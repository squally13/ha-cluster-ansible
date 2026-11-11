# Implementation Plan: Etap 2 — Baza danych z replikacją source → replica (GTID)

**Branch**: `002-etap2-mysql-replikacja` | **Date**: 2026-11-11 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/002-etap2-mysql-replikacja/spec.md`

## Summary

Etap 2 dodaje warstwę bazy na `db1`/`db2`: MySQL 8.4.13 z oficjalnego repozytorium Oracle dla
Debiana 13 (dokładnie przypięta łatka), konfigurację z szablonów (statyczna + dynamiczny plik
roli), replikację asynchroniczną GTID z auto-pozycjonowaniem po kanale TLS oraz automatyczne
zasilanie pustej repliki wtyczką Clone — jedna ścieżka dla świeżego labu, odtworzenia jednego
węzła i przyłączenia starego źródła po promowaniu. `root` bazy uwierzytelnia się gniazdem
(bez hasła); hasła kont `repl`, `clone`, `app` są w Ansible Vault (pierwsze użycie w projekcie).
Przełączenie bazy jest ręczne (runbook), a rola chroni przed niezgodnością repo ↔ stan węzła.
Decyzje: [research.md](research.md).

## Technical Context

**Language/Version**: YAML (Ansible), Jinja2, Python 3.13 (Debian 13 — moduły i skrypt testu),
SQL (MySQL 8.4)

**Primary Dependencies**: MySQL Community Server `8.4.13-1debian13` (repo.mysql.com,
komponent `mysql-8.4-lts`); kolekcja `ansible.mysql` 5.2.0; `python3-pymysql` 1.1.1 (Debian)
na węzłach `db`; PyMySQL 1.1.1 w venv `ops` (tylko testy); z etapu 1: ansible-core 2.21.6,
`ansible.posix` 2.2.2, `community.general` 14.0.0, nftables

**Storage**: InnoDB na węzłach `db` (`/var/lib/mysql`); sekrety w
`inventories/lab/group_vars/all/vault.yml` (Ansible Vault); zrzut przed promowaniem w
`/var/backups/mysql/` na promowanym węźle

**Testing**: `site.yml` ×2 (`changed=0`), `--check --diff`, `playbooks/verify/stage2.yml` +
regresja `stage1.yml`, testy ręczne z [quickstart.md](quickstart.md) (restart repliki, odtworzenie
`db2`, runbook w obie strony), lint (pre-commit + CI)

**Target Platform**: lab z etapu 1 — 7 × Debian 13 amd64, VirtualBox na Windowsie; bazy tylko
na `db1`/`db2` (1,5 GB RAM)

**Project Type**: repozytorium infrastruktury jako kod (Ansible + Vagrant)

**Performance Goals**: wiersz z `db1` widoczny na `db2` ≤ 5 s (SC-003); `vagrant up` + przebieg 1
≤ 30 min (SC-006); runbook promowania ≤ 10 min (SC-007)

**Constraints**: zero ręcznych kroków na bazie poza runbookiem; brak zapisów SQL na replice poza
klonem i konfiguracją replikacji (errant GTID); brak sekretów w Git i logach; firewall: 3306 tylko
dla `web` + drugiego `db`; dokładne przypięcie wersji (R1)

**Scale/Scope**: 2 węzły bazy, 2 nowe role, 3 nowe playbooki (`preflight`, `db`, `verify/stage2`),
1 runbook, 6 ADR (0010–0015), 1 tutorial

Brak pozycji NEEDS CLARIFICATION — rozstrzygnięte w [research.md](research.md) (R1–R12).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Zasada | Jak plan ją spełnia | Status |
|---|---|---|
| I. Wszystko jako kod | repozytorium Oracle, klucz, wersja, `my.cnf`, konta, replikacja, klon, firewall — w rolach; wersje przypięte dokładnie (MySQL R1, `ansible.mysql`, PyMySQL); jedyne kroki ręczne to runbook promowania — wyjątek wymieniony wprost w zasadzie I | ✅ |
| II. Idempotencja (NON-NEGOTIABLE) | `getreplica` przed `changereplication`; klon tylko na pustym węźle; konta `update_password: on_create`; `root` bez hasła (brak porównań skrótów); `role.cnf` stosowany `SET GLOBAL` bez restartu; zadania odczytu `changed_when: false`; test z zapisami między przebiegami (quickstart 2); odtworzenie od zera ×3 | ✅ |
| III. Konwencje ról | zmienne `mysql_*`/`mysql_replication_*` w `defaults/`, nadpisywane w `group_vars`/`host_vars`; całe pliki z szablonów z nagłówkiem; handlery `Restart mysql`, `Apply mysql role settings`; `validate:` dla `mysqld.cnf` (R4, z planem awaryjnym w handlerze); tagi `mysql`, `mysql-install`, `mysql-config`, `mysql-accounts`, `replication`; lint | ✅ |
| IV. Sekrety w Vault | `vault.yml` zaszyfrowany, `vault_*` → zmienne jawne; `.vault_pass` w `.gitignore` (od etapu 1); `no_log` na zadaniach z hasłami; preflight przed zmianami; `tools/init-vault.sh` dla Recenzenta | ✅ |
| V. ADR | 6 ADR (lista niżej); README: deklaracja ręcznego failoveru bazy | ✅ |
| VI. Dokumentacja jako tutorial | `docs/stages/02-mysql-replikacja.md`, runbook `docs/runbooks/mysql-promote-replica.md` (przetestowany w obie strony), `docs/notes.md` | ✅ |
| Git i przepływ | gałąź `002-etap2-mysql-replikacja`, Issues + Project, PR z PLAY RECAP, `main` chroniony (`lint`) | ✅ |
| Definicja ukończenia | odtworzenie od zera ×3, `changed=0`, lint, ADR, tutorial + runbook, PR z PLAY RECAP i linkami | ✅ (plan w tasks) |
| Zasady dodatkowe | granica projektu jawnie: ręczny failover bazy (ADR 0012, README); firewall drop + 3306 tylko dla wskazanych źródeł | ✅ |

**Wynik bramki przed Phase 0**: PASS.

**Ponowna ocena po Phase 1**: PASS (z jednym jawnym odstępstwem — Complexity Tracking).
Po `/speckit-analyze` poprawiono: definicję węzła „pustego” (H1), kolejność kontroli zgodności
w `db.yml` (H2), pamięć z `vagrant_memory` (M4), ponawianie połączenia repliki (M2). Doprecyzowania spec wynikające z projektu (bez naruszeń):
FR-004 — konto administracyjne przez gniazdo zamiast hasła z Vaulta (bezpieczniejsze, R3);
FR-009 — konta `repl`/`clone` z adresów obu węzłów `db` (wymagane po promowaniu, R5). Spec
zaktualizowana. Playbooki weryfikacyjne nie należą do `site.yml`.

## Project Structure

### Documentation (this feature)

```text
specs/002-etap2-mysql-replikacja/
├── plan.md              # ten plik
├── research.md          # Phase 0 — R1–R12
├── data-model.md        # Phase 1 — encje, stan węzła, macierz zgodności
├── quickstart.md        # Phase 1 — przewodnik walidacji
├── contracts/
│   ├── mysql-roles.md       # interfejs ról mysql i mysql_replication, preflight, db.yml
│   └── verification.md      # verify/stage2.yml + zmiana w verify/stage1 (port 9999)
├── checklists/requirements.md
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
./
├── requirements.yml                 # + ansible.mysql 5.2.0
├── requirements-ops.txt             # + PyMySQL==1.1.1 (testy z węzłów WWW, R11)
├── vagrant/bootstrap-ops.sh         # + export ANSIBLE_VAULT_PASSWORD_FILE=/vagrant/.vault_pass
├── tools/init-vault.sh              # NOWY: własny .vault_pass + vault.yml z losowymi hasłami
├── inventories/lab/
│   ├── group_vars/all/vault.yml     # NOWY, zaszyfrowany: vault_mysql_{repl,clone,app}_password
│   ├── group_vars/db.yml            # NOWY: mysql_*_password: "{{ vault_... }}", nadpisania
│   └── host_vars/{db1,db2}.yml      # NOWE: mysql_server_id, mysql_role
├── roles/
│   ├── mysql/
│   │   ├── defaults/main.yml
│   │   ├── handlers/main.yml        # Restart mysql, Apply mysql role settings
│   │   ├── tasks/{main,assert,repo,install,config,firewall,secure,accounts}.yml
│   │   ├── templates/{mysqld.cnf,role.cnf,mysql.sources,mysql.pref,nftables.nft}.j2
│   │   ├── files/mysql-2025.asc     # klucz podpisu Oracle (RPM-GPG-KEY-mysql-2025)
│   │   └── meta/main.yml
│   └── mysql_replication/
│       ├── defaults/main.yml
│       ├── tasks/{main,state,consistency,clone,replication}.yml
│       └── meta/main.yml
├── playbooks/
│   ├── site.yml                     # preflight → common → db
│   ├── preflight.yml                # NOWY: assert sekretów Vault
│   ├── db.yml                       # NOWY: kontrola zgodności → mysql → mysql_replication
│   └── verify/
│       ├── stage1/us4.yml           # ZMIANA: port 9999 (FR-021)
│       ├── stage2.yml + stage2/{us1,us2,us4,us5}.yml
│       └── files/mysql_probe.py     # NOWY
├── docs/
│   ├── adr/0010…0015
│   ├── stages/02-mysql-replikacja.md
│   ├── stages/01-fundament.md       # adnotacja: test firewalla na 9999
│   ├── runbooks/mysql-promote-replica.md
│   ├── architecture.md              # warstwa bazy, porty 3306
│   └── notes.md
└── README.md                        # „Decyzje projektowe”: ręczny failover bazy, Vault dla Recenzenta
```

**Structure Decision**: zgodnie z sekcją 4 planu projektu (`roles/mysql`,
`roles/mysql_replication`, `playbooks/db.yml`), plus `playbooks/preflight.yml` (wczesny błąd
Vaulta), `tools/` (inicjalizacja Vaulta) i `docs/runbooks/` (pierwszy runbook). Testy US3 są
ręczne (wymagają przebiegu `site.yml`), dlatego brak `stage2/us3.yml`.

## ADR-y do napisania w etapie 2

| Nr | Tytuł | Źródło |
|---|---|---|
| 0010 | MySQL 8.4 LTS z repozytorium Oracle dla Debiana 13, dokładne przypięcie łatki | R1 |
| 0011 | Replikacja asynchroniczna GTID z auto-pozycjonowaniem; kanał TLS bez weryfikacji tożsamości | R5 |
| 0012 | Ręczne przełączenie bazy (runbook); stare źródło zawsze zasilane od nowa; ochrona repo ↔ stan | spec Q1, R8 |
| 0013 | Ansible Vault: plik hasła poza Gitem przez zmienną środowiskową; własny Vault Recenzenta | R7 |
| 0014 | Zasilanie repliki wtyczką Clone (jedna ścieżka dla każdej pustej repliki) | spec Q2, R6 |
| 0015 | `root` bazy przez `auth_socket` zamiast hasła | R3 |

## Ryzyka i pozycje do weryfikacji na starcie implementacji

| Ryzyko | Sygnał | Reakcja |
|---|---|---|
| Oracle wyda 8.4.14 w trakcie etapu | `apt` nie znajduje `8.4.13-1debian13` | podbicie `mysql_version`, wpis w `docs/notes.md` (ADR 0010 to przewiduje) |
| `/etc/mysql/my.cnf` pakietu nie dołącza `mysql.conf.d/` | `mysqld --print-defaults` bez naszych opcji | szablon całego `/etc/mysql/my.cnf` |
| `mysqld --validate-config` jako `validate:` nie działa na pliku tymczasowym | błąd walidacji poprawnego pliku | walidacja całości w handlerze przed restartem (wzorzec chrony z etapu 1) |
| Klon nie restartuje serwera pod systemd | po `CLONE INSTANCE` usługa `inactive` | `systemd: state=started` + `wait_for` po klonie |
| Pakiet startuje serwer z domyślną konfiguracją przed naszym `mysqld.cnf` | błąd startu po włączeniu `gtid_mode=ON` | szablony w `mysql.conf.d/` wgrane **przed** instalacją pakietu |
| `caching_sha2_password` bez TLS w kanale replikacji | `Last_IO_Error: ... requires secure connection` | `primary_ssl: true` (R5); sprawdzenie `Source_SSL_Allowed: Yes` |
| Za mało RAM na `db` | OOM w `journalctl -k` | niższy `mysql_innodb_buffer_pool_size`, wyłączony `performance_schema` |
| `ansible-lint` w CI a zaszyfrowany `vault.yml` | błąd lintu | wykluczenie pliku w `.ansible-lint` (lint nie potrzebuje treści) |

## Complexity Tracking

| Odstępstwo | Dlaczego potrzebne | Prostsza/zgodna alternatywa odrzucona, bo |
|---|---|---|
| Zasada IV wymienia „hasło root MySQL” wśród sekretów w Vault, a `root` bazy nie ma hasła (`auth_socket`) | Konto tylko lokalne z natury; brak sekretu do wycieku; brak `changed` przy porównaniu skrótu `caching_sha2_password` (zasada II) | hasło `root` w Vault wymaga dodatkowego pliku z sekretem na węźle (`~/.my.cnf`) i `update_password: on_create` (rozjazd Vault ↔ baza po zmianie hasła). Odstępstwo opisane w ADR 0015; zakres: tylko konto `root@localhost`; usunięcie: brak planu — decyzja docelowa |
