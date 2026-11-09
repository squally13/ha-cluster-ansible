# Implementation Plan: Etap 1 — Fundament

**Branch**: `001-etap1-fundament` | **Date**: 2026-11-08 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-etap1-fundament/spec.md`

## Summary

Etap 1 dostarcza powtarzalne środowisko 7 maszyn Debian 13 (Vagrant + VirtualBox na Windowsie)
i rolę Ansible `common`, która doprowadza każdy węzeł do bezpiecznego stanu bazowego: konto
`admin` z kluczem labu, SSH bez haseł i roota, `/etc/hosts` z inventory, UTC + chrony, nftables z
polityką `drop` (otwarty tylko SSH z `ops`, z hosta do `ops` i kanał zarządzania Vagranta),
automatyczne poprawki bezpieczeństwa bez restartów. Ansible działa na `ops` z folderu
współdzielonego; minimalny bootstrap Vagranta tworzy konto `admin` i parę kluczy labu. Jakość
pilnują `pre-commit` i GitHub Actions, a scenariusze akceptacyjne automatyzuje playbook
`playbooks/verify/stage1.yml`. Decyzje: [research.md](research.md).

## Technical Context

**Language/Version**: YAML (Ansible), Jinja2, Ruby (Vagrantfile), Bash (bootstrap), Python 3.13
(z Debiana 13 — interpreter Ansible i skrypt testu połączeń)

**Primary Dependencies**: ansible-core 2.21.6 (przypięty — R7, weryfikacja w `docs/notes.md`), kolekcje
`ansible.posix`, `community.general`; Vagrant 2.4.x; VirtualBox 7.x; obraz `bento/debian-13`
(przypięta wersja — R2); nftables, chrony, openssh-server, unattended-upgrades, needrestart

**Storage**: N/A (stan deklaratywny w repo; para kluczy labu w `.lab/` poza Gitem)

**Testing**: drugi przebieg `site.yml` (`changed=0`), `--check --diff`, playbook
`playbooks/verify/stage1.yml` (R13), `yamllint` + `ansible-lint` (pre-commit + GitHub Actions),
kroki ręczne z [quickstart.md](quickstart.md)

**Target Platform**: host Windows 10/11 z VirtualBoxem (możliwy współistniejący Hyper-V — R14);
goście Debian 13 amd64; sieć host-only 192.168.56.0/24

**Project Type**: repozytorium infrastruktury jako kod (Ansible + Vagrant)

**Performance Goals**: od `vagrant up` do końca pierwszego przebiegu ≤ 30 min (SC-003); drugi
przebieg bez zmian

**Constraints**: ~7 GB RAM dla maszyn; repo na NTFS z końcami linii LF (R1); brak sekretów w
Git; brak automatycznych restartów; kolejność zmian bez utraty dostępu (FR-018)

**Scale/Scope**: 7 węzłów, 1 rola (`common`), 1 playbook główny + 1 weryfikacyjny, ~9 ADR

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Zasada | Jak plan ją spełnia | Status |
|---|---|---|
| I. Wszystko jako kod | Vagrantfile, bootstrap, rola `common`, CI w repo; wersje przypięte (box, ansible-core, kolekcje, lintery); brak ręcznych zmian na węzłach (bootstrap to kod) | ✅ |
| II. Idempotencja i odtwarzalność (NON-NEGOTIABLE) | drugi przebieg `changed=0`; ryzyka zidentyfikowane i zaadresowane: hostname vs Vagrant (R4), pełny upgrade tylko raz (R11), cache apt (R11 — weryfikacja), bootstrap idempotentny (R5); quickstart wymaga destroy + 2 przebiegów ×3 | ✅ |
| III. Konwencje ról | zmienne `common_*` w `defaults/`, całe pliki z szablonów z nagłówkiem, handlery, `validate:` dla sshd i nft, tagi per obszar ([contracts/common-role.md](contracts/common-role.md)), lint lokalnie + CI | ✅ |
| IV. Sekrety w Vault | etap 1 bez sekretów; klucz prywatny labu poza Gitem (`.lab/` w `.gitignore`); `.vault_pass` w `.gitignore` od początku; `vault.yml` od etapu 2 (R15) | ✅ |
| V. ADR | 9 ADR-ów zaplanowanych (lista niżej) | ✅ |
| VI. Dokumentacja jako tutorial | `docs/stages/01-fundament.md` w układzie co/dlaczego/komenda/weryfikacja/typowe problemy; `docs/notes.md` od pierwszego dnia; quickstart jako szkielet | ✅ |
| Git i przepływ | gałąź etapu, PR z PLAY RECAP, lint blokuje merge; **warunek wstępny**: `git init` + repo GitHub (katalog nie jest jeszcze repo Git) | ✅ (z warunkiem) |

**Wynik bramki przed Phase 0**: PASS — brak naruszeń wymagających uzasadnienia.

**Ponowna ocena po Phase 1**: PASS. Projekt dodał bootstrap powłoki poza Ansible (R5) — to nie
narusza zasady I (kod w repo, idempotentny, minimalny zakres) i jest opisany w ADR 0005.
Playbook weryfikacyjny nie należy do `site.yml`, więc nie wpływa na `changed=0`.

## Project Structure

### Documentation (this feature)

```text
specs/001-etap1-fundament/
├── plan.md              # ten plik
├── research.md          # Phase 0 — decyzje R1–R15
├── data-model.md        # Phase 1 — encje i reguły
├── quickstart.md        # Phase 1 — przewodnik walidacji
├── contracts/
│   ├── common-role.md       # interfejs roli common (zmienne, tagi, handlery, gwarancje)
│   ├── firewall-dropin.md   # jak kolejne role otwierają porty
│   └── verification.md      # playbook weryfikacyjny i oczekiwane wyniki
├── checklists/requirements.md
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
./                                  # repo (na NTFS, R1)
├── README.md                       # szybki start + link do tutorialu etapu 1
├── Vagrantfile                     # czyta inventories/lab/hosts.yml (R3), generuje .lab/ssh (R5)
├── .gitattributes                  # * text=auto eol=lf
├── .gitignore                      # .lab/, .vault_pass, .vagrant/
├── ansible.cfg                     # inventory, roles_path, remote_user=admin, private_key_file
├── requirements.yml                # kolekcje z dokładnymi wersjami
├── requirements-ops.txt            # ansible-core==X.Y.Z (instalowany na ops)
├── requirements-dev.txt            # yamllint, ansible-lint, pre-commit (host/CI)
├── .pre-commit-config.yaml
├── .yamllint
├── .ansible-lint
├── vagrant/
│   ├── bootstrap-node.sh           # konto admin + klucz publiczny labu (wszystkie węzły)
│   └── bootstrap-ops.sh            # venv /opt/ansible, kolekcje, klucz prywatny dla admin
├── inventories/lab/
│   ├── hosts.yml                   # jedyne źródło listy maszyn (IP, vagrant_memory, grupy)
│   ├── group_vars/all/main.yml     # common_vip_address, common_ssh_host_address, ...
│   └── host_vars/ops.yml           # ansible_connection: local
├── roles/common/
│   ├── defaults/main.yml
│   ├── handlers/main.yml
│   ├── tasks/{main,packages,users,hosts,time,firewall,ssh,updates}.yml
│   ├── templates/{sshd_config,sudoers_admin,hosts,chrony.conf,nftables.conf,50unattended-upgrades,20auto-upgrades,needrestart.conf}.j2
│   └── meta/main.yml
├── playbooks/
│   ├── site.yml                    # w etapie 1: import common.yml
│   ├── common.yml                  # hosts: all, rola common
│   └── verify/
│       ├── stage1.yml              # testy akceptacyjne (R13): importuje stage1/usN.yml z tagami usN
│       ├── stage1/{us1,us3,us4,us5}.yml
│       └── files/tcp_probe.py      # sonda TCP: RESULT=connected|refused|timeout
├── docs/
│   ├── adr/0000-szablon.md + 0001…0009
│   ├── stages/01-fundament.md      # tutorial etapu 1
│   ├── architecture.md             # szkic: adresacja, porty etapu 1
│   └── notes.md
└── .github/workflows/lint.yml
```

**Structure Decision**: układ z sekcji 4 planu projektu, z trzema świadomymi zmianami:
`vagrant/` na skrypty bootstrapu (R5), `playbooks/common.yml` jako playbook warstwy bazowej
importowany przez `site.yml` (spójnie z `db.yml`/`web.yml`/`lb.yml` w kolejnych etapach) oraz
`playbooks/verify/` na testy akceptacyjne etapów. Katalogi `app/`, `playbooks/chaos/` i role
kolejnych etapów powstaną w swoich etapach.

## ADR-y do napisania w etapie 1

| Nr | Tytuł | Źródło |
|---|---|---|
| 0001 | Debian 13 jako system wszystkich węzłów | Q2, R2 |
| 0002 | Vagrant + VirtualBox na Windowsie; repo na NTFS; współistnienie z Hyper-V | Q1, R1, R14 |
| 0003 | `ops` jako węzeł sterujący; źródła SSH | Q3, Q5, R9 |
| 0004 | Firewall: nftables, w etapie 1 tylko SSH, porty usług otwierane przez role etapów (fragmenty) | sprzeczność planu, R8 |
| 0005 | Bootstrap: para kluczy labu i konto `admin` przed Ansible | Clarify Q3, R5 |
| 0006 | Konto `vagrant`: zostaje, hasło zablokowane, SSH tylko z kanału NAT | Clarify Q4 |
| 0007 | Aktualizacje: tylko security, bez automatycznych restartów, jednorazowy pełny upgrade | Clarify Q2, R11 |
| 0008 | Repo na `ops` przez folder współdzielony (tylko na `ops`, uprawnienia 755/644) | Clarify Q1, R6 |
| 0009 | Jedno źródło listy maszyn: `hosts.yml` czytany przez Vagrantfile | R3, R4 |

## Ryzyka i pozycje do weryfikacji na starcie implementacji

| Ryzyko | Sygnał | Reakcja |
|---|---|---|
| Brak `bento/debian-13` dla VirtualBoxa lub bez dodatków gościa | `vagrant box add` nie znajduje wersji / `mount -t vboxsf` błąd | inny obraz z dodatkami gościa; aktualizacja ADR 0001/0008 |
| VirtualBox na Hyper-V zbyt wolny | SC-003 > 30 min, zawieszenia | obejście z R14; wpis w ADR 0002 i `docs/notes.md` |
| `apt` raportuje `changed` przy odświeżeniu cache | drugi przebieg `changed>0` na zadaniu pakietów | `changed_when` oparty na wyniku instalacji |
| `include` z wzorcem w nft przy pustym katalogu | błąd `nft -c -f` | plik zastępczy `00-placeholder.nft` z komentarzem |
| SSH w Debianie 13 socket-activated | handler restartuje niewłaściwą jednostkę | handler na właściwej jednostce (weryfikacja `systemctl status ssh.socket`) |
| Repo obecnie w WSL (`~/klaster-ha`) | — | przeniesienie na NTFS jako pierwsze zadanie |

## Complexity Tracking

Brak naruszeń konstytucji — sekcja nie ma zastosowania.
