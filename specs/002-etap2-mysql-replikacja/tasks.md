---

description: "Task list for Etap 2 — Baza danych z replikacją source → replica (GTID)"
---

# Tasks: Etap 2 — Baza danych z replikacją source → replica (GTID)

**Input**: Design documents from `/specs/002-etap2-mysql-replikacja/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: spec wymaga playbooka weryfikacyjnego (FR-020) i regresji etapu 1 (FR-021, SC-009).
Każda historyjka z testami automatycznymi ma zadanie `playbooks/verify/stage2/usN.yml`
(kontrakt: [contracts/verification.md](contracts/verification.md)) pisane **przed**
implementacją; jego porażka przed wdrożeniem jest zapisywana w `docs/notes.md`. US3 i US6 są
testowane ręcznie wg [quickstart.md](quickstart.md).

**Organization**: zadania pogrupowane według historyjek ze spec. Ścieżki względem korzenia repo
(`/mnt/c/Users/Arek/projects/ha-homelab`, gałąź `002-etap2-mysql-replikacja`).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: można wykonywać równolegle (inne pliki, brak zależności od niedokończonych zadań)
- **[Story]**: historyjka ze spec (US1…US7)

## Konwencje obowiązujące w każdym zadaniu (konstytucja + etap 1)

- Zmienne z prefiksem roli (`mysql_`, `mysql_replication_`) w `roles/<rola>/defaults/main.yml`;
  nadpisywanie tylko w `inventories/lab/group_vars|host_vars` albo `-e` (tylko
  `mysql_replication_reseed`).
- Każdy szablon zaczyna się nagłówkiem `# Zarządzane przez Ansible — nie edytuj ręcznie`.
- Restart/zastosowanie ustawień wyłącznie przez handlery z
  [contracts/mysql-roles.md](contracts/mysql-roles.md); `command`/`shell` z `changed_when`.
- Każde zadanie z `name` po polsku i tagiem z kontraktu; zadania z hasłami `no_log: true`.
- Połączenie z bazą z Ansible: `login_unix_socket: /var/run/mysqld/mysqld.sock`, `become: true`
  (konto `root` przez `auth_socket` — R3). Na replice **żadnych zapisów SQL** poza klonem i
  konfiguracją replikacji (errant GTID — R6, R12).
- Lokalny `ansible-playbook`/lint w WSL: `ANSIBLE_CONFIG=$PWD/ansible.cfg`; przebiegi na labie z
  `ops` (`admin`, `/vagrant`). Commity z WSL z venv `~/.venvs/ha-homelab` (hook pre-commit).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: organizacja pracy, weryfikacja faktów z research, zależności i Vault.

- [ ] T001 Załóż w GitHubie (`gh`) label `etap-2`, Issues US1–US7 i „Etap 2: zamknięcie etapu” z kryteriami akceptacji ze `specs/002-etap2-mysql-replikacja/spec.md` (wzorzec: skrypt z T002 etapu 1), zmień nazwę istniejącego Projectu nr 2 na „HA cluster” (jedna tablica dla całego projektu, etap rozróżnia label `etap-N`) i dodaj do niego nowe Issues ze statusem Todo; numery Issues wpisz w nowej sekcji `## Etap 2` w `docs/notes.md`
- [ ] T002 Zweryfikuj na starcie pozycje [WERYFIKACJA] z `research.md`: wersja `mysql-community-server` w `https://repo.mysql.com/apt/debian/dists/trixie/mysql-8.4-lts/binary-amd64/Packages` (oczekiwane `8.4.13-1debian13`; jeśli nowsza — użyj jej w T012 i zapisz), najnowsza `ansible.mysql` na Galaxy (5.2.0), odcisk klucza `RPM-GPG-KEY-mysql-2025` (`gpg --show-keys`); wyniki w `docs/notes.md`
- [ ] T003 [P] Dodaj kolekcję `ansible.mysql` w wersji `5.2.0` do `requirements.yml` (komentarz: moduły przeniesione z `community.mysql` 5.x — R2)
- [ ] T004 [P] Dodaj `PyMySQL==1.1.1` do `requirements-ops.txt` (tylko testy z węzłów WWW — R11)
- [ ] T005 [P] W `vagrant/bootstrap-ops.sh` dopisz idempotentnie do `.profile` konta `admin` `export ANSIBLE_VAULT_PASSWORD_FILE=/vagrant/.vault_pass` (wzorzec: istniejący wpis `ANSIBLE_CONFIG`) — R7; sprawdź, że bootstrap instaluje kolekcje z `requirements.yml` i pakiety z `requirements-ops.txt` przy każdym `vagrant provision ops`
- [ ] T006 [P] Utwórz `tools/init-vault.sh` (bash, `set -euo pipefail`, uruchamiany na `ops` w `/vagrant`): tworzy `.vault_pass` (losowe 32 znaki, `chmod 600` gdzie możliwe), jeśli nie istnieje; generuje `inventories/lab/group_vars/all/vault.yml` z `vault_mysql_repl_password`, `vault_mysql_clone_password`, `vault_mysql_app_password` (losowe, bez znaków `'"\`) i szyfruje `ansible-vault encrypt`; odmawia nadpisania istniejącego `vault.yml` bez `--force` — R7
- [ ] T007 Uruchom `tools/init-vault.sh` na `ops`, zatwierdź zaszyfrowany `inventories/lab/group_vars/all/vault.yml`; potwierdź `git check-ignore .vault_pass` i `ansible-vault view` (3 zmienne)
- [ ] T008 [P] Sprawdź `ansible-lint` i `yamllint` z zaszyfrowanym `vault.yml` lokalnie i w CI; w razie błędu wyklucz plik w `.ansible-lint` (`exclude_paths`) i `.yamllint` (`ignore`) z komentarzem

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: zmienne, szkielety ról, playbooki i narzędzia testowe — wspólne pliki powstają w
całości tutaj, żeby historyjki nie edytowały tych samych plików.

**⚠️ CRITICAL**: żadna historyjka nie zaczyna się przed końcem tej fazy.

- [ ] T009 [P] Utwórz `inventories/lab/host_vars/db1.yml` (`mysql_server_id: 1`, `mysql_role: source`) i `inventories/lab/host_vars/db2.yml` (`mysql_server_id: 2`, `mysql_role: replica`) — reguły z data-model: „> 0, unikalny w grupie `db`”, „dokładnie **jeden** host `db` ma `source`”
- [ ] T010 [P] Utwórz `inventories/lab/group_vars/db.yml`: `mysql_repl_password: "{{ vault_mysql_repl_password }}"`, `mysql_clone_password: "{{ vault_mysql_clone_password }}"`, `mysql_app_password: "{{ vault_mysql_app_password }}"` (zasada IV)
- [ ] T011 [P] Utwórz `playbooks/preflight.yml` wg [contracts/mysql-roles.md](contracts/mysql-roles.md): `hosts: localhost`, `gather_facts: false`, `assert` (z `no_log: true`) że trzy zmienne `vault_mysql_*` są zdefiniowane i niepuste, z komunikatem odsyłającym do `tools/init-vault.sh`
- [ ] T012 Utwórz szkielet roli `roles/mysql/`: `defaults/main.yml` ze wszystkimi zmiennymi z tabeli „Ustawienia grupy” w `data-model.md` (`mysql_version: "8.4.13-1debian13"` lub wartość z T002, `mysql_apt_component: mysql-8.4-lts`, `mysql_innodb_buffer_pool_size: "{{ ((vagrant_memory | default(1536) | int) * 0.25) | int }}M"` (FR-006: 25% RAM węzła z inventory), `mysql_max_connections: 100`, `mysql_binlog_expire_logs_seconds: 604800`, `mysql_app_database: app`, `mysql_app_user: app`, `mysql_repl_user: repl`, `mysql_clone_user: clone`, `mysql_socket: /var/run/mysqld/mysqld.sock`, `mysql_config_dir: /etc/mysql/mysql.conf.d`); `meta/main.yml`; `handlers/main.yml` z `Restart mysql` (restart + `wait_for` port 3306 na `ansible_host`) i `Apply mysql role settings` (`ansible.mysql.mysql_query` z `SET GLOBAL read_only`, `super_read_only`, `clone_valid_donor_list` wg roli węzła); `tasks/main.yml` importujący w kolejności `assert.yml`, `repo.yml`, `config.yml`, `install.yml`, `firewall.yml`, `secure.yml`, `accounts.yml`, `app.yml` z tagami z kontraktu (`secure`, `accounts`, `app` z `when: mysql_role == 'source'`), `meta: flush_handlers` po `install.yml` oraz `role_drift.yml` po `flush_handlers` (przed `firewall.yml`); puste pliki zadań z samym `---` i komentarzem, który US je wypełnia
- [ ] T013 Utwórz szkielet roli `roles/mysql_replication/`: `defaults/main.yml` (`mysql_replication_reseed: ""`, `mysql_replication_wait_seconds: 60`), `meta/main.yml`, `tasks/check.yml` importujący `state.yml` i `consistency.yml` (używany też przez pierwszy play `db.yml`), `tasks/main.yml` importujący `check.yml`, `clone.yml`, `replication.yml` (tag `replication`); puste pliki zadań
- [ ] T014 Utwórz `playbooks/db.yml` (trzy playe wg kontraktu, wszystkie `hosts: db`, `become: true`: 1) kontrola zgodności — `include_role mysql_replication tasks_from=check.yml` tylko gdy `/usr/sbin/mysqld` istnieje (FR-018: przed rolą `mysql`, która wgrywa `role.cnf`), 2) rola `mysql` z tagiem `mysql`, 3) `mysql_replication` z tagiem `replication`) i zmień `playbooks/site.yml` na import `preflight.yml` → `common.yml` → `db.yml`
- [ ] T015 [P] Utwórz `playbooks/verify/files/mysql_probe.py` (Python 3, tylko `pymysql` + biblioteka standardowa): argumenty `--host --port --user --password-env NAZWA --database --sql`; wypisuje jedną linię `RESULT=ok|denied|readonly|error HOST=... USER=... DETAIL=...` (kod 1045 → `denied`, 1290/1836 → `readonly`); hasło tylko ze zmiennej środowiskowej, nigdy w argumentach
- [ ] T016 [P] Utwórz `playbooks/verify/stage2.yml` importujący `stage2/us1.yml`, `stage2/us2.yml`, `stage2/us4.yml`, `stage2/us5.yml` (tagi `us1`, `us2`, `us4`, `us5`) oraz wspólne zmienne (adresy z inventory, `verify_pymysql_dir`); utwórz puste pliki `playbooks/verify/stage2/us{1,2,4,5}.yml`
- [ ] T017 Przenieś test firewalla etapu 1 na port 9999 (FR-021, R10): w `playbooks/verify/stage1/us4.yml` zmienna `us4_probe_port: 9999` zamiast literału `3306` (nasłuch, `wait_for`, sondy); adnotacja w `specs/001-etap1-fundament/contracts/verification.md` i w sekcji Krok 8 `docs/stages/01-fundament.md` („od etapu 2 port 9999, bo 3306 jest zajęty i celowo otwarty”); uruchom `verify/stage1.yml --tags us4` na obecnym labie → zielony
- [ ] T018 Checkpoint: na `ops` `ansible-galaxy collection install -r requirements.yml`, `ansible-playbook playbooks/site.yml` → `preflight` zielony, `db.yml` przechodzi z pustymi zadaniami, 7/7 `changed=0`; `ANSIBLE_VAULT_PASSWORD_FILE= ansible-playbook playbooks/site.yml` → błąd przed `common.yml` (edge case Vault)

**Checkpoint**: fundament gotowy — historyjki mogą ruszać.

---

## Phase 3: User Story 1 — Baza danych na obu węzłach `db` (Priority: P1) 🎯 MVP

**Goal**: MySQL 8.4 z przypiętej wersji na `db1`/`db2`, konfiguracja z szablonów, bez kont
anonimowych i bazy `test`, `root` tylko przez gniazdo.

**Independent Test**: `ansible-playbook playbooks/verify/stage2.yml --tags us1` → `failed=0`.

### Tests for User Story 1

- [ ] T019 [US1] Napisz `playbooks/verify/stage2/us1.yml` wg tabeli `us1` w [contracts/verification.md](contracts/verification.md) (US1.1 wersja/usługa, US1.2 konta i bazy, `root@localhost` z `auth_socket`, US1.3 `server_id`/`gtid_mode`/`log_bin`, US1.5 brak `mysql.service` poza `db`); uruchom przed implementacją → porażka zapisana w `docs/notes.md`

### Implementation for User Story 1

- [ ] T020 [P] [US1] Pobierz `https://repo.mysql.com/RPM-GPG-KEY-mysql-2025` do `roles/mysql/files/mysql-2025.asc` (odcisk z T002 w komentarzu w `repo.yml`); utwórz `roles/mysql/templates/mysql.sources.j2` (deb822: `Types: deb`, `URIs: http://repo.mysql.com/apt/debian`, `Suites: {{ ansible_distribution_release }}`, `Components: {{ mysql_apt_component }}`, `Signed-By: /etc/apt/keyrings/mysql.asc`) i `roles/mysql/templates/mysql.pref.j2` (`Package: mysql-*` → `Pin: version {{ mysql_version }}`, `Pin-Priority: 1001`)
- [ ] T021 [US1] Wypełnij `roles/mysql/tasks/repo.yml`: katalog `/etc/apt/keyrings`, klucz, `/etc/apt/sources.list.d/mysql.sources`, `/etc/apt/preferences.d/mysql.pref`; odświeżenie cache apt tylko po zmianie źródeł (`changed_when` jak w `roles/common/tasks/packages.yml`)
- [ ] T022 [P] [US1] Utwórz `roles/mysql/templates/mysqld.cnf.j2` (sekcja `[mysqld]`: `server_id = {{ mysql_server_id }}`, `bind_address = {{ ansible_host }}`, `gtid_mode = ON`, `enforce_gtid_consistency = ON`, `log_bin = mysql-bin`, `binlog_format = ROW`, `relay_log = relay-bin`, `binlog_expire_logs_seconds`, `innodb_buffer_pool_size`, `max_connections`, `plugin-load-add = mysql_clone.so`) i `roles/mysql/templates/role.cnf.j2` (replika: `read_only = ON`, `super_read_only = ON`, `clone_valid_donor_list = <adres źródła>:3306`; źródło: `read_only = OFF`, `super_read_only = OFF`) — R4
- [ ] T023 [US1] Wypełnij `roles/mysql/tasks/config.yml`: katalog `{{ mysql_config_dir }}`; szablony `mysqld.cnf` (`notify: Restart mysql`) i `role.cnf` (`notify: Apply mysql role settings`) wgrywane **przed** instalacją pakietu (ryzyko z plan.md: pierwszy start pakietu z `gtid_mode=ON`); `validate: mysqld --defaults-file=%s --validate-config --user=mysql` tylko gdy `/usr/sbin/mysqld` istnieje (`stat` wcześniej + `omit`) — przy pierwszej instalacji plik powstaje bez walidacji, bo nie ma jeszcze binarki ani działającej usługi do zepsucia; dlatego w `install.yml` zaraz po instalacji pakietu zadanie `mysqld --validate-config` (`changed_when: false`) na pełnej konfiguracji; jeśli walidacja fragmentu nie działa — walidacja całości w handlerze przed restartem (wzorzec chrony z etapu 1) i wpis w `docs/notes.md`
- [ ] T024 [US1] Wypełnij `roles/mysql/tasks/install.yml`: `debconf` `mysql-community-server/root-pass` i `re-root-pass` puste (`no_log`), instalacja `mysql-server`, `mysql-community-server`, `mysql-client` w wersji `{{ mysql_version }}` oraz `python3-pymysql`, usługa `mysql` `enabled` + `started`; sprawdź `mysqld --print-defaults`, że opcje z `mysql.conf.d/` są czytane (jeśli nie — szablon `/etc/mysql/my.cnf`, wpis w `docs/notes.md`)
- [ ] T025 [US1] Wypełnij `roles/mysql/tasks/assert.yml`: `mysql_role` ∈ {`source`, `replica`}; unikalne `mysql_server_id` > 0 w `groups['db']`; dokładnie jeden host z `mysql_role == 'source'` (`run_once: true`)
- [ ] T026 [US1] Wypełnij `roles/mysql/tasks/secure.yml` (tylko źródło): `mysql_user` `state: absent` dla `''@localhost`, `''@{{ ansible_hostname }}`, `root` z hostów `%`, `127.0.0.1`, `::1`; `mysql_db name=test state=absent`
- [ ] T027 [US1] Uruchom `site.yml` ×2 na labie (przebieg 2: 7/7 `changed=0`), `verify/stage2.yml --tags us1` → zielony; test US1.4 wg quickstart krok 4 (zły szablon → błąd walidacji, usługa działa); wyniki i problemy w `docs/notes.md`
- [ ] T028 [P] [US1] Napisz `docs/adr/0010-mysql-84-repo-oracle.md` (R1: źródło pakietów, dokładne przypięcie łatki, co zrobić po wydaniu nowej łatki, alternatywy: MariaDB, 9.7 LTS, `pool/`) i `docs/adr/0015-root-auth-socket.md` (R3 — sformułowany jako **świadome odstępstwo** od zapisu zasady IV „hasło root MySQL w Vault”: powód, zakres `root@localhost`, brak planu usunięcia; zgodnie z Governance konstytucji) wg `docs/adr/0000-szablon.md`

**Checkpoint**: obie bazy działają z przypiętą wersją; US1 zielony.

---

## Phase 4: User Story 2 — Replikacja `db1` → `db2` automatycznie (Priority: P1)

**Goal**: replika zasilana klonem i replikująca przez GTID po TLS, bez ręcznych kroków.

**Independent Test**: `verify/stage2.yml --tags us2` → `failed=0`; quickstart kroki 3, 5, 6.

### Tests for User Story 2

- [ ] T029 [US2] Napisz `playbooks/verify/stage2/us2.yml` wg tabeli `us2` (US2.1 wątki i opóźnienie, US2.2 zapis w bazie `verify_stage2` na źródle → odczyt na replice z pomiarem czasu ≤ 5 s i `DROP DATABASE` w `always`, US2.3 `Source_Host`/`Auto_Position`/`Source_User`/`Source_SSL_Allowed`, US2.4 `mysql_probe.py` z `web1` kontem `repl` → `denied`, z kopiowaniem `pymysql` z venv `ops` do katalogu tymczasowego i sprzątaniem w `always` — R11); uruchom przed implementacją → porażka w `docs/notes.md`

### Implementation for User Story 2

- [ ] T030 [US2] Wypełnij `roles/mysql/tasks/firewall.yml` i utwórz `roles/mysql/templates/nftables.nft.j2` wg kontraktu `specs/001-etap1-fundament/contracts/firewall-dropin.md`: `/etc/nftables.d/mysql.nft`, jedna reguła `add rule inet filter input ip saddr { <adresy groups['web'] + groups['db'] bez własnego> } tcp dport 3306 accept comment "mysql: web + db"`, `notify: reload firewall`
- [ ] T031 [US2] Wypełnij `roles/mysql/tasks/accounts.yml` (tylko źródło, `no_log: true`, `update_password: on_create`): `repl` z każdego adresu `groups['db']` z `priv: '*.*:REPLICATION SLAVE'`; `clone` z każdego adresu `groups['db']` z `priv: '*.*:BACKUP_ADMIN'` — tabela „Encje w bazie” w `data-model.md`
- [ ] T032 [US2] Wypełnij `roles/mysql_replication/tasks/state.yml`: `mysql_replication mode=getreplica`, zapytania o schematy użytkownika (bez `mysql`, `sys`, `information_schema`, `performance_schema`) i obecność kont `repl`, `clone`, `app` w `mysql.user` (`mysql_query`, `changed_when: false`); fakty `mysql_replication_state` (`is_replica`, `source_host`, `io_error`, `sql_error`, `empty`) — definicja „pusty” z `data-model.md`: „`is_replica == false` **i** `user_schemas == []` **i** brak kont `repl`, `clone`, `app` w `mysql.user`” (**nie** `gtid_executed` — `postinst` pakietu tworzy transakcje GTID już przy instalacji)
- [ ] T033 [US2] Wypełnij `roles/mysql_replication/tasks/consistency.yml`: wszystkie wiersze macierzy zgodności z `data-model.md` jako `fail` z komunikatem-instrukcją (po polsku, z odesłaniem do runbooka) — przed jakąkolwiek zmianą (FR-018, FR-013); `Source_Host` porównuj z `hostvars[<źródło z repo>].ansible_host` (adres IP, nie nazwa). Test kolejności: promowany `db2` bez zmiany repo → `site.yml` zatrzymuje się w pierwszym playu `db.yml`, a `@@super_read_only` na `db2` pozostaje `0`
- [ ] T034 [US2] Wypełnij `roles/mysql_replication/tasks/clone.yml` (tylko replika, gdy `empty` lub `inventory_hostname == mysql_replication_reseed`): `mysql_query` `CLONE INSTANCE FROM '{{ mysql_clone_user }}'@'<adres źródła>':3306 IDENTIFIED BY ... REQUIRE SSL` (`no_log`, błąd rozłączenia po restarcie traktowany jako oczekiwany), potem `systemd state=started`, `wait_for` port 3306, ponowne `state.yml` — R6
- [ ] T035 [US2] Wypełnij `roles/mysql_replication/tasks/replication.yml` (tylko replika, gdy `is_replica == false`): `mysql_replication mode=changereplication` (`primary_host` = adres źródła, `primary_user`/`primary_password` konta `repl`, `primary_auto_position: true`, `primary_ssl: true`, `primary_connect_retry: 10`, `no_log`), `mysql_query` `CHANGE REPLICATION SOURCE TO SOURCE_RETRY_COUNT = 86400` (moduł nie ma tej opcji; domyślne 10 prób — research R5, [WERYFIKACJA] `SELECT * FROM performance_schema.replication_connection_configuration`), `mode=startreplica`; pętla `getreplica` do `mysql_replication_wait_seconds` aż oba wątki `Yes` (`changed_when: false`)
- [ ] T036 [US2] Uruchom na świeżym labie (`vagrant destroy -f db1 db2 && vagrant up db1 db2`) `site.yml` ×2 (przebieg 2 `changed=0`), `verify/stage2.yml --tags us2` → zielony; quickstart krok 3 (US2.5 restart repliki), krok 5 (SC-010 odtworzenie `db2` z danymi na źródle), krok 6 (ochrona przed nadpisaniem, `mysql_replication_reseed`); restart labu w złej kolejności: `vagrant halt db1 db2`, `vagrant up db2`, po 3 min `vagrant up db1` → replikacja wraca bez ingerencji (edge case „replika startuje przed źródłem”); wyniki w `docs/notes.md`
- [ ] T037 [P] [US2] Napisz `docs/adr/0011-replikacja-async-gtid.md` (R5: asynchroniczna, auto-pozycjonowanie, kanał TLS bez weryfikacji tożsamości, możliwa utrata niezreplikowanych transakcji, co na produkcji) i `docs/adr/0014-zasilanie-repliki-clone.md` (R6: jedna ścieżka, errant GTID, ochrona przed nadpisaniem)

**Checkpoint**: replikacja zestawiana automatycznie w każdym przypadku z FR-012.

---

## Phase 5: User Story 3 — Idempotencja: ponowny przebieg nie rusza replikacji (Priority: P1)

**Goal**: `changed=0` także przy zapisach między przebiegami; replikacja nie restartowana.

**Independent Test**: quickstart krok 2.

- [ ] T038 [US3] Wykonaj quickstart krok 2: dane testowe na `db1`, zapis `gtid_executed` i `SHOW REPLICA STATUS` na `db2`, `site.yml` + `--check --diff` → 7/7 `changed=0`, brak różnic, `gtid_executed` się nie cofa; każdą przyczynę `changed>0` napraw w odpowiednim pliku zadań roli i opisz w `docs/notes.md` (typowe: `mysql_user` z hasłem, `apt` cache, handler `Apply mysql role settings` wywoływany bez zmiany)

**Checkpoint**: zasada II spełniona przy żywej replikacji.

---

## Phase 6: User Story 4 — Replika tylko do odczytu (Priority: P1)

**Goal**: każdy zapis na replice odrzucony, od startu usługi.

**Independent Test**: `verify/stage2.yml --tags us4` → `failed=0`.

- [ ] T039 [US4] Napisz `playbooks/verify/stage2/us4.yml` wg tabeli `us4` (US4.1 `mysql_probe.py` z `web1` kontem `app` → `readonly` — wymaga konta `app` z US5, do tego czasu test oznaczony `skip` z komunikatem; US4.2 `root` przez gniazdo `CREATE DATABASE` na replice → błąd `super-read-only`; US4.3 `@@read_only`, `@@super_read_only` = 1 i oba w `role.cnf`) i uruchom
- [ ] T040 [US4] Wypełnij `roles/mysql/tasks/role_drift.yml` (importowany w `main.yml` po `flush_handlers` — T012) kontrolą dryfu: `mysql_query` odczytuje `@@read_only`, `@@super_read_only` i porównuje z rolą węzła; przy rozbieżności (np. ręczne `SET GLOBAL super_read_only=OFF` na replice) wywołuje `Apply mysql role settings` (`changed_when` tylko przy rozbieżności). Sprawdź: `vagrant reload db2` → `@@super_read_only = 1` od startu; ręczne `SET GLOBAL super_read_only=OFF` + `site.yml` → `db2 changed=1`, potem `changed=0`; wynik w `docs/notes.md`

**Checkpoint**: replika chroniona przed zapisem (SC-004).

---

## Phase 7: User Story 5 — Baza i konto aplikacji z dostępem tylko z węzłów WWW (Priority: P2)

**Goal**: baza `app`, konto `app` tylko z `web1`/`web2`; port 3306 tylko dla wskazanych źródeł.

**Independent Test**: `verify/stage2.yml --tags us5` → `failed=0`.

- [ ] T041 [US5] Napisz `playbooks/verify/stage2/us5.yml` wg tabeli `us5` (US5.1 `app` z `web1`/`web2` → `ok` + `SHOW GRANTS` tylko `app.*`; US5.2 `app` z `db2` na `db1` → `denied`; US5.3/5.4 `tcp_probe.py` → `db1:3306`/`db2:3306` z `lb1`, `ops` → `timeout`, z `web1`, `web2`, drugiego `db` → `connected`); uruchom przed implementacją → porażka w `docs/notes.md`
- [ ] T042 [US5] Wypełnij `roles/mysql/tasks/app.yml` (tylko źródło): `mysql_db name={{ mysql_app_database }} encoding=utf8mb4`; `mysql_user` `{{ mysql_app_user }}` z każdego adresu `groups['web']`, `priv: '{{ mysql_app_database }}.*:ALL'`, `update_password: on_create`, `no_log: true`
- [ ] T043 [US5] Uruchom `site.yml` ×2 (`changed=0`), `verify/stage2.yml --tags us4,us5` → zielony (US4.1 bez `skip`); US5.5: tymczasowa kopia inventory z dodanym `web3` + `ansible-playbook playbooks/db.yml -i <kopia> --check --diff --limit db` → diff reguły nft i nowe konto `app@<adres web3>`; wynik w `docs/notes.md`

**Checkpoint**: przygotowanie pod etap 3 gotowe (SC-005).

---

## Phase 8: User Story 6 — Ręczne promowanie repliki według runbooka (Priority: P2)

**Goal**: przetestowany runbook w obie strony; repo nie cofa promowania.

**Independent Test**: quickstart krok 7.

- [ ] T044 [US6] Napisz `docs/runbooks/mysql-promote-replica.md` wg R8 w formacie zasady VI (co / dlaczego / komenda z hostem / weryfikacja z oczekiwanym wynikiem / typowe problemy): kryterium decyzji; zrzut `mysqldump --single-transaction --all-databases --source-data=2` do `/var/backups/mysql/` (FR-019); `STOP REPLICA; RESET REPLICA ALL; SET GLOBAL super_read_only=OFF, read_only=OFF`; zmiana `mysql_role` w `inventories/lab/host_vars/db1.yml`/`db2.yml` + commit; `site.yml --limit 'all:!<stare źródło>'`; przyłączenie starego źródła: uruchamiać je dopiero, gdy zmiana ról jest w repo, i zaraz po starcie (wstaje zapisywalne — od etapu 3 aplikacja musi wskazywać nowe źródło), porównanie GTID `SELECT GTID_SUBTRACT(<gtid_executed starego źródła>, <gtid_executed nowego>)` i zapis utraconych transakcji, potem `-e mysql_replication_reseed=<host>`; powrót tym samym runbookiem w drugą stronę (wariant planowany: `Seconds_Behind_Source: 0` i wstrzymanie zapisów zamiast awarii)
- [ ] T045 [US6] Wykonaj runbook wg quickstart krok 7 w obie strony: zapis kontrolny, `vagrant halt db1`, promowanie `db2` (czas ≤ 10 min — SC-007), zapis kontem `app` z `web1` na `db2`, `site.yml` ×2 (`changed=0`, `db2` nie wraca do repliki), `vagrant up db1` + reseed, powrót; `verify/stage2.yml` zielony na końcu; każde miejsce, w którym runbook był niejasny, popraw w `docs/runbooks/mysql-promote-replica.md`; czasy i wyniki w `docs/notes.md` (SC-011)
- [ ] T046 [P] [US6] Napisz `docs/adr/0012-reczny-failover-bazy.md` (ręczne przełączenie, stare źródło zawsze zasilane od nowa, macierz zgodności repo ↔ stan, alternatywy: Orchestrator, InnoDB Cluster, Pacemaker z agentem MySQL; co na produkcji)

**Checkpoint**: granica projektu (ręczny failover) przetestowana i opisana.

---

## Phase 9: User Story 7 — Dokumentacja etapu jako tutorial i decyzje w ADR (Priority: P3)

**Goal**: Recenzent odtwarza etap 2 z dokumentacji; decyzje w ADR; README z deklaracją.

**Independent Test**: przegląd wg zasady VI; komplet ADR 0010–0015.

- [ ] T047 [P] [US7] Napisz `docs/adr/0013-ansible-vault.md` (R7: plik hasła poza Gitem przez `ANSIBLE_VAULT_PASSWORD_FILE`, preflight, własny Vault Recenzenta przez `tools/init-vault.sh`, `no_log`)
- [ ] T048 [US7] Napisz `docs/stages/02-mysql-replikacja.md` jako tutorial (wzorzec `docs/stages/01-fundament.md`): wymagania (etap 1, Vault), kroki: Vault → repozytorium i instalacja → konfiguracja (dwa pliki, dlaczego) → firewall → konta → replikacja i klon → test zapisu/odczytu → tylko do odczytu → konto `app` → idempotencja → odtworzenie repliki → odsyłacz do runbooka; w każdym kroku co/dlaczego/komenda/weryfikacja (np. `Replica_IO_Running: Yes`)/typowe problemy (błąd 1236, 1062, `Last_IO_Error` przy braku TLS, brak `.vault_pass`, nowa łatka MySQL, OOM); tabela „Typowe problemy — przegląd”
- [ ] T049 [P] [US7] Zaktualizuj `README.md`: sekcja „Decyzje projektowe” z jawną deklaracją „failover bazy jest ręczny” → runbook + ADR 0012; Vault dla Recenzenta (`tools/init-vault.sh`); link do tutorialu etapu 2; linki ADR 0010–0015
- [ ] T050 [P] [US7] Zaktualizuj `docs/architecture.md`: warstwa bazy (role węzłów, kierunek replikacji, konta), port 3306 i jego źródła, przełączenie ręczne

**Checkpoint**: dokumentacja kompletna (zasady V i VI).

---

## Phase 10: Polish & Cross-Cutting Concerns (zamknięcie etapu)

**Purpose**: definicja ukończenia etapu z konstytucji.

- [ ] T051 Przejrzyj `roles/mysql/` i `roles/mysql_replication/` pod kątem zasady III: szablony z nagłówkiem, brak `lineinfile`, brak bezwarunkowych restartów, walidacja konfiguracji, `name` + tag w każdym zadaniu, `no_log` na zadaniach z hasłami, `changed_when` na `command`/`mysql_query` odczytujących; `ansible-lint` bez nieuzasadnionych wyjątków
- [ ] T052 Sprawdź sekrety (SC-008): `git log -p --all | grep -iE "password|haslo"` → tylko odwołania `vault_*`/nazwy zmiennych; log pełnego przebiegu `site.yml -v` bez haseł w postaci jawnej; `vault.yml` zaczyna się od `$ANSIBLE_VAULT`
- [ ] T053 Wykonaj quickstart krok 8 (brak hasła do Vaulta → błąd w `playbooks/preflight.yml`, brak zmian na węzłach); wynik w `docs/notes.md`
- [ ] T054 Wykonaj pełne odtworzenie od zera 3 razy z rzędu (FR-022, SC-001): `vagrant destroy -f && vagrant up`, na `ops`: `site.yml` ×2, `--check --diff`, `verify/stage1.yml` + `verify/stage2.yml` (wzorzec skryptu z T065 etapu 1, z dodaną weryfikacją etapu 2); przebieg 1 `failed=0 unreachable=0`, przebieg 2 `changed=0` na 7/7, replikacja działa; czasy SC-006 dopisz do tabeli w `docs/adr/0002-vagrant-virtualbox-windows.md` jako pomiar etapu 2
- [ ] T055 Uzupełnij `docs/notes.md` o wszystkie problemy etapu; powtarzalne przenieś do „Typowe problemy” w `docs/stages/02-mysql-replikacja.md`
- [ ] T056 Utwórz pull request `002-etap2-mysql-replikacja` → `main` (`gh pr create`): zakres, PLAY RECAP obu przebiegów z T054, wynik weryfikacji etapów 1 i 2, czas SC-006, wyniki runbooka (T045), linki do ADR 0010–0015, `Closes #...` Issues z T001; lint zielony; merge commitem po akceptacji użytkownika
- [ ] T057 Oznacz kamienie milowe tagami (konstytucja, sekcja Git): `m1` na commicie scalenia etapu 1 (`fdbf3c2`) i `m2` na commicie scalenia etapu 2; `git push --tags`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: T002 przed T012 (wersja MySQL); T003–T006 równolegle; T006 → T007; T007 → T008.
- **Foundational (Phase 2)**: zależy od Setup; T012, T013 → T014; T009–T011, T015, T016 równolegle; T017 niezależne; T018 na końcu. **Blokuje US1–US7.**
- **US1 (Phase 3)**: po Foundational. MVP.
- **US2 (Phase 4)**: po US1 (potrzebuje działającej bazy na obu węzłach).
- **US3 (Phase 5)**: po US2 (testuje idempotencję przy żywej replikacji); powtarzana po US4, US5.
- **US4 (Phase 6)**: po US2 (replika musi istnieć); US4.1 pełny dopiero po US5.
- **US5 (Phase 7)**: po US2 (konto `app` trafia na replikę przez replikację; firewall z T030).
- **US6 (Phase 8)**: po US2, US4, US5 (runbook używa konta `app` i trybu tylko do odczytu).
- **US7 (Phase 9)**: ADR-y od razu po decyzjach; T048 po US1–US6.
- **Polish (Phase 10)**: po wszystkich historyjkach; T056 po T054; T057 po merge.

### Within Each User Story

- Test (`playbooks/verify/stage2/usN.yml`) przed implementacją, porażka w `docs/notes.md`.
- Szablony przed zadaniami, które ich używają.
- Po implementacji: `site.yml` ×2 (`changed=0`) → test historyjki → ADR.

### Parallel Opportunities

- Setup: T003, T004, T005, T006 razem; T008 równolegle z Phase 2.
- Foundational: T009, T010, T011, T015, T016, T017 razem.
- US1: T020 i T022 razem (różne szablony); T028 równolegle z T027.
- US2: T037 równolegle z T036.
- US6/US7: T046, T047, T049, T050 razem.

---

## Parallel Example: Foundational

```bash
Task: "Utwórz host_vars/db1.yml i db2.yml (T009)"
Task: "Utwórz group_vars/db.yml (T010)"
Task: "Utwórz playbooks/preflight.yml (T011)"
Task: "Utwórz playbooks/verify/files/mysql_probe.py (T015)"
Task: "Utwórz playbooks/verify/stage2.yml (T016)"
Task: "Przenieś test us4 etapu 1 na port 9999 (T017)"
```

## Parallel Example: User Story 1

```bash
Task: "Klucz Oracle + mysql.sources.j2 + mysql.pref.j2 (T020)"
Task: "mysqld.cnf.j2 + role.cnf.j2 (T022)"
# po T027:
Task: "ADR 0010 i 0015 (T028)"
```

---

## Implementation Strategy

### MVP First (User Story 1)

1. Phase 1 + Phase 2 → Vault, szkielety, preflight, regresja etapu 1 (port 9999).
2. Phase 3: US1 → obie bazy działają, `changed=0`.
3. **STOP and VALIDATE**: `vagrant destroy -f db1 db2 && vagrant up db1 db2` + `site.yml` → US1 zielony.

### Incremental Delivery

1. US1 → US2 (replikacja + klon) → US3 (idempotencja z zapisami).
2. US4 → US5 → US3 ponownie.
3. US6 (runbook w obie strony) → US7 (tutorial, README, ADR).
4. Phase 10: 3× odtworzenie, PR, tagi.

### Commity

Małe commity `<obszar>: <co zmieniono>`, np. `mysql: add Oracle apt repo pinned to 8.4.13`,
`mysql_replication: seed empty replica with clone plugin`, `verify: move stage 1 firewall probe
to port 9999`, `docs: add ADR 0012 manual database failover`.

---

## Notes

- [P] = różne pliki, brak zależności od niedokończonych zadań.
- `roles/mysql/tasks/main.yml`, `defaults/main.yml`, `handlers/main.yml` i
  `roles/mysql_replication/tasks/main.yml` powstają w całości w Phase 2, żeby historyjki nie
  edytowały tych samych plików.
- Testy z węzłów WWW nie zostawiają `pymysql` na węzłach (sprzątanie w `always`).
- Każdy problem trwający > 2 h → Issue z listą sprawdzonych hipotez (konstytucja, sekcja Git).
