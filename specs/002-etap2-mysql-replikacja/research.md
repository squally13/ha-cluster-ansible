# Research: Etap 2 — Baza danych z replikacją source → replica (GTID)

**Data**: 2026-11-11 | **Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

Format: Decyzja / Uzasadnienie / Alternatywy. Fakty sprawdzone 2026-11-11 bezpośrednio u źródeł
(indeks repozytorium `repo.mysql.com`, pakiet `.deb` rozpakowany na `db1`, API Ansible Galaxy,
kod modułów kolekcji). **[WERYFIKACJA]** = do potwierdzenia w pierwszym przebiegu.

---

## R1. Źródło pakietów MySQL 8.4 dla Debiana 13

- **Fakty**: `https://repo.mysql.com/apt/debian/dists/trixie/Release` (2026-10-22) zawiera
  komponent `mysql-8.4-lts` (także `mysql-9.7-lts`, `mysql-innovation`). W indeksie
  `mysql-8.4-lts/binary-amd64/Packages` jest **tylko najnowsza łatka**: `mysql-community-server
  8.4.13-1debian13`. Starsze łatki (8.4.10, 8.4.11 dla `debian13`) leżą w `pool/`, ale nie ma ich
  w indeksie, więc `apt` ich nie zainstaluje.
- **Decyzja**: oficjalne repozytorium Oracle dodawane bezpośrednio (plik `sources` z
  `Signed-By` + klucz `RPM-GPG-KEY-mysql-2025` w repo roli), komponent `mysql-8.4-lts`, bez
  pakietu `mysql-apt-config` (interaktywny debconf). Wersja przypięta **dokładnie**
  (`mysql_version: "8.4.13-1debian13"`) przez `apt_preferences` z priorytetem 1001 dla pakietów
  `mysql-*`.
- **Konsekwencja przypięcia**: gdy Oracle wyda 8.4.14, wersja 8.4.13 zniknie z indeksu i
  odtworzenie od zera zatrzyma się na instalacji z czytelnym błędem. Naprawa to zmiana jednej
  zmiennej (+ wpis w `docs/notes.md`). Świadomy kompromis: powtarzalność i jawna zmiana wersji w
  historii Git zamiast cichej aktualizacji. ADR 0010.
- **Alternatywy**: MariaDB z Debiana (stabilna wersja w repo dystrybucji, ale plan i ogłoszenie
  wymagają MySQL, a GTID MariaDB jest niezgodny); MySQL 9.7 LTS (nowsza linia LTS, ale plan
  przypina 8.4, a kolekcja Ansible testuje oba — zostaje jako rozszerzenie); instalacja `.deb`
  z `pool/` po URL (pozwala trzymać starą łatkę, ale ręczne rozwiązywanie 7 zależności pakietów);
  wersja `8.4.*` bez dokładnej łatki (ciche aktualizacje między odtworzeniami — zasada I).

## R2. Kolekcja Ansible i sterownik

- **Fakty**: `community.mysql` 5.x nie zawiera już modułów — przeniesiono je do
  **`ansible.mysql`** (przekierowania zostały). Najnowsza `ansible.mysql` 5.2.0 (2026-07-16):
  ansible-core 2.17–2.21 (nasz 2.21.6 ✓), testowana z MySQL 8.4.9 i 9.7.0, sterownik
  **PyMySQL** (wsparcie `mysqlclient` usunięte w 5.0). Debian 13 ma `python3-pymysql 1.1.1` —
  wersja z macierzy testów kolekcji.
- **Decyzja**: `ansible.mysql` 5.2.0 w `requirements.yml`; na węzłach `db` pakiet
  `python3-pymysql` z Debiana. Moduły: `mysql_db`, `mysql_user`, `mysql_replication`
  (`getreplica`, `changereplication`, `startreplica`), `mysql_query`, `mysql_info`.
- **Alternatywy**: `community.mysql` 4.x (ostatnia z modułami, ale gałąź porzucona);
  polecenia `mysql -e` w `command` (trudna idempotencja, hasła w linii poleceń).

## R3. Konto administracyjne bazy: `auth_socket` zamiast hasła

- **Fakty** (postinst `mysql-community-server_8.4.13-1debian13`): gdy debconf
  `mysql-community-server/root-pass` jest pusty, pakiet wykonuje `mysqld --initialize-insecure`,
  a następnie `INSTALL PLUGIN auth_socket` i `ALTER USER 'root'@'localhost' IDENTIFIED WITH
  'auth_socket'`.
- **Decyzja**: `root@localhost` uwierzytelniany **gniazdem uniksowym** (tylko systemowy `root`
  na węźle), bez hasła. Ansible łączy się jako `root` przez `login_unix_socket` z `become`.
  Instalacja z pustym `root-pass` (debconf ustawiony przed instalacją, `DEBIAN_FRONTEND`
  nieinteraktywny). „Secure installation”: usunięcie kont anonimowych, `root` spoza
  `localhost` i bazy `test` (idempotentnie, `mysql_user`/`mysql_db` z `state: absent`).
- **Odstępstwo od zapisu konstytucji**: zasada IV wymienia „hasło root MySQL” wśród sekretów w
  Vault. Brak hasła nie łamie reguły (żaden sekret nie leży poza Vaultem), ale zmienia jej
  założenie — zgodnie z Governance zapisane jawnie w ADR 0015 i w Complexity Tracking planu.
- **Uzasadnienie**: brak hasła = brak sekretu do wycieku i brak klasycznego `changed` przy
  `caching_sha2_password` (losowa sól, moduł nie porówna skrótu); konto z natury tylko lokalne
  (FR-004). Doprecyzowuje FR-004 spec (hasło z magazynu → uwierzytelnianie gniazdem) —
  spec zaktualizowana.
- **Alternatywy**: hasło `root` z Vaulta + `~/.my.cnf` dla `root` (dodatkowy plik z sekretem
  na węźle, `update_password` zawsze `changed` lub tylko `on_create`).

## R4. Konfiguracja serwera: plik statyczny + plik roli (dynamiczny)

- **Decyzja**: dwa szablony w `/etc/mysql/mysql.conf.d/` **[WERYFIKACJA: katalog dołączany
  przez `/etc/mysql/my.cnf` pakietu Oracle]**:
  1. `mysqld.cnf` — ustawienia wymagające restartu: `server_id`, `bind_address`, `gtid_mode`,
     `enforce_gtid_consistency`, `log_bin`, `binlog_format=ROW`, `relay_log`,
     `binlog_expire_logs_seconds`, `innodb_buffer_pool_size`, `max_connections`,
     `plugin-load-add=mysql_clone.so`. Zmiana → handler `Restart mysql`.
  2. `role.cnf` — ustawienia zależne od roli węzła i **dynamiczne**: `read_only`,
     `super_read_only`, `clone_valid_donor_list`. Zmiana → handler `Apply mysql role settings`
     (`SET GLOBAL ...` przez `mysql_query`) zamiast restartu.
- **Uzasadnienie**: promowanie repliki (US6) zmienia tylko `role.cnf`; przebieg po promowaniu
  nie restartuje świeżo promowanego źródła (brak dodatkowej przerwy). Plik i tak obowiązuje od
  startu (US4.3).
- **Walidacja**: `validate: mysqld --defaults-file=%s --validate-config --user=mysql`
  **[WERYFIKACJA]** (pakiet nie ma profilu AppArmor, więc problem z etapu 1 z chrony nie
  powinien wystąpić; gdyby walidacja pojedynczego fragmentu nie działała — jak w etapie 1:
  walidacja całości w handlerze przed restartem).
- **Pamięć (FR-006)**: `innodb_buffer_pool_size` = 25% `vagrant_memory` węzła z inventory
  (1,5 GB → 384M; reszta dla systemu, buforów połączeń i `performance_schema`),
  `max_connections` 100; wartości w `defaults/` z możliwością nadpisania.
- **Retencja binlogów (FR-007)**: `binlog_expire_logs_seconds` = 604800 (7 dni). Nowa replika
  nie zależy od binlogów sprzed klonowania (R6).

## R5. Replikacja: GTID, auto-pozycjonowanie, kanał szyfrowany

- **Decyzja**: replikacja asynchroniczna z `SOURCE_AUTO_POSITION=1`, ustawiana modułem
  `mysql_replication` `mode: changereplication` z `primary_ssl: true`, potem `startreplica`.
  Konto `repl` z `REPLICATION SLAVE`.
- **Fakt**: domyślny plugin w 8.4 to `caching_sha2_password`; połączenie replikacji bez TLS
  wymaga `GET_SOURCE_PUBLIC_KEY=1`, a moduł (5.2.0) **nie ma** tej opcji. MySQL 8.4 sam generuje
  certyfikaty przy starcie, więc `SOURCE_SSL=1` działa bez dodatkowej konfiguracji (szyfrowanie
  bez weryfikacji tożsamości serwera — ograniczenie w ADR 0011).
- **Konta replikacji i klonowania z adresów wszystkich węzłów `db`** (wyliczanych z inventory),
  nie tylko „bieżącej repliki”: po promowaniu role się zamieniają, a konta są już na obu węzłach
  dzięki replikacji. Spełnia cel FR-009 (żaden węzeł spoza `db` nie użyje konta) — spec
  doprecyzowana.
- **Ponawianie połączenia**: moduł ma `primary_connect_retry` (ustawiamy 10 s), ale nie liczbę
  prób; domyślne `SOURCE_RETRY_COUNT` w 8.4 to 10 **[WERYFIKACJA]**, czyli replika uruchomiona
  przed źródłem poddaje się po kilku minutach. Przy konfiguracji (tylko gdy `is_replica` jest
  fałszywe) dodatkowo `mysql_query`: `CHANGE REPLICATION SOURCE TO SOURCE_RETRY_COUNT = 86400`
  (≈ 10 dni prób) — restart całego labu w dowolnej kolejności nie zatrzymuje replikacji.
- **Idempotencja**: `mode: getreplica` przed zmianą; `changereplication`/`startreplica` tylko gdy
  `Is_Replica` jest fałszywe. Jeśli replikacja jest skonfigurowana, ale `Last_IO_Error` lub
  `Last_SQL_Error` nie są puste — `fail` z treścią błędu (FR-013), bez resetu.
- **Alternatywy**: replikacja półsynchroniczna (wymaga drugiej repliki, by nie blokować zapisów
  przy awarii — poza zakresem); Group Replication / InnoDB Cluster (plan: rozszerzenie);
  `mysql_query` z ręcznym `CHANGE REPLICATION SOURCE ... GET_SOURCE_PUBLIC_KEY=1` (działa, ale
  moduł daje gotowe `getreplica`).

## R6. Zasilenie pustej repliki: wtyczka Clone (FR-012, SC-010)

- **Decyzja**: wbudowana wtyczka `clone` (`plugin-load-add=mysql_clone.so` na obu węzłach).
  Gdy węzeł z rolą `replica` jest „pusty” (definicja w [data-model.md](data-model.md)), rola
  wykonuje na nim `SET GLOBAL clone_valid_donor_list` (z `role.cnf`) i `CLONE INSTANCE FROM
  'clone'@'<source>':3306 IDENTIFIED BY ... REQUIRE SSL`, czeka na restart serwera i dopiero
  potem konfiguruje replikację. Konto `clone` na źródle z `BACKUP_ADMIN`.
- **Aktualizacja (implementacja, T008)**: `ansible.mysql` 5.2.0 zawiera moduł **`mysql_clone`**
  (od 5.1.0): wykonuje `CLONE INSTANCE ... REQUIRE SSL`, czeka na restart odbiorcy i ponowne
  połączenie oraz na stan końcowy klonu. Używany zamiast `mysql_query` (moduł nie jest
  idempotentny — wywołanie chronione warunkiem „pusty” lub `reseed`, jak w planie).
- **Fakty**: jednostka `mysql.service` pakietu ma `RestartForceExitStatus=16` i
  `MYSQLD_PARENT_PID=1` — serwer po klonowaniu restartuje się sam pod systemd. Klon przenosi
  `gtid_executed` źródła, więc auto-pozycjonowanie GTID dociąga wyłącznie zapisy wykonane po
  klonowaniu (brak luki — edge case „zapisy w trakcie zasilania”).
- **Jedna ścieżka dla wszystkich przypadków**: replika w świeżym labie także jest klonowana
  (źródło prawie puste). Zaleta: replika nigdy nie ma własnych transakcji (tzw. errant GTID) —
  np. operacji z instalacji pakietu — które blokowałyby późniejsze promowanie.
- **„Pusty” bez `gtid_executed`** (poprawka po `/speckit-analyze`): skrypt `postinst` pakietu
  wykonuje `INSTALL PLUGIN`/`ALTER USER` przy naszej konfiguracji z GTID, więc świeża replika ma
  niepuste `gtid_executed`. Kryterium: brak replikacji, brak schematów użytkownika i brak kont
  `repl`/`clone`/`app` (te konta tworzy wyłącznie rola na źródle).
- **Ochrona danych**: klonowanie nigdy nie startuje na węźle z danymi, chyba że Administrator
  jawnie wskaże go zmienną `-e mysql_replication_reseed=<host>` (krok runbooka przy
  przyłączaniu starego źródła — R8).
- **Alternatywy**: `mysqldump`/`mysqlpump` + import (wolniejsze, ręczne GTID_PURGED, ryzyko
  przy zapisach w trakcie); XtraBackup (zewnętrzne narzędzie, brak pakietu dla 8.4 z repo
  Oracle); replikacja od zera bez zasilenia (wymaga pełnej historii binlogów — sprzeczne z
  retencją R4).

## R7. Sekrety: Ansible Vault (pierwsze użycie w projekcie)

- **Decyzja**: `inventories/lab/group_vars/all/vault.yml` zaszyfrowany `ansible-vault`
  (`vault_mysql_repl_password`, `vault_mysql_clone_password`, `vault_mysql_app_password`);
  jawne `mysql_*_password: "{{ vault_... }}"` w `group_vars/db.yml`/`all/main.yml`. Hasło do
  Vaulta w `.vault_pass` w katalogu repo (już w `.gitignore` od etapu 1), wskazane zmienną
  `ANSIBLE_VAULT_PASSWORD_FILE` ustawianą w `.profile` konta `admin` na `ops` przez bootstrap —
  **nie** w `ansible.cfg`, żeby lint w CI nie wymagał hasła.
- **Recenzent nie zna hasła autora**: tutorial każe wygenerować własne `.vault_pass` i własny
  `vault.yml` skryptem `tools/init-vault.sh` (losowe hasła, nadpisuje lokalnie zaszyfrowany
  plik autora). ADR 0013.
- **Wczesny błąd (edge case)**: `playbooks/preflight.yml` importowany jako pierwszy w
  `site.yml` — `assert` na zmiennych `vault_*` na `localhost` (`run_once`); brak hasła lub zły
  plik kończy przebieg przed jakąkolwiek zmianą na węzłach.
- **Logi**: `no_log: true` na zadaniach z hasłami (`mysql_user`, `changereplication`, klon).
- **Alternatywy**: hasła w `host_vars` jawnie (zasada IV — nie); zewnętrzny menedżer sekretów
  (poza zakresem labu); `vault_password_file` w `ansible.cfg` (psuje CI).

## R8. Promowanie repliki i przyłączenie starego źródła (US6, FR-017/018)

- **Decyzja — runbook `docs/runbooks/mysql-promote-replica.md`**:
  1. Kryterium: `db1` niedostępny i nie wróci szybko (nie promujemy przy chwilowym zaniku).
  2. Zrzut logiczny `db2` przed promowaniem (`mysqldump --single-transaction --all-databases
     --source-data=2` do `/var/backups/mysql/` na `db2`) — FR-019.
  3. Na `db2`: `STOP REPLICA; RESET REPLICA ALL; SET GLOBAL super_read_only=OFF,
     read_only=OFF` (ręczne — dozwolony wyjątek z zasady I).
  4. W repo: zamiana `mysql_role` w `host_vars/db1.yml` i `db2.yml`; commit.
  5. `ansible-playbook playbooks/site.yml --limit 'all:!db1'` — `role.cnf` na `db2` zmienia się,
     handler stosuje `SET GLOBAL` (bez restartu); reguły i konta bez zmian.
  6. Po powrocie `db1` (uruchamiany dopiero, gdy krok 4 jest w repo — `db1` wstaje
     zapisywalny ze starym `role.cnf`; od etapu 3 aplikacja musi już wskazywać `db2`):
     najpierw porównanie GTID — na `db1` `SELECT GTID_SUBTRACT(@@gtid_executed, '<gtid_executed
     z db2>')` → transakcje, które nie dotarły na `db2` przed awarią, zapisywane w
     `docs/notes.md` (i w zrzucie `db1`); potem `ansible-playbook playbooks/site.yml -e
     mysql_replication_reseed=db1` — `db1` jest zawsze **zasilany od nowa** klonem z `db2` i
     dołącza jako replika.
  7. Powrót do układu wyjściowego = ten sam runbook w drugą stronę (planowany: krok 1 zastąpiony
     sprawdzeniem `Seconds_Behind_Source: 0` i zatrzymaniem zapisów).
- **Ochrona przed przywróceniem starego układu (FR-018)**: pierwszy play `db.yml` (przed rolą
  `mysql`, która wgrywa `role.cnf`) porównuje rolę z inventory ze stanem węzła (macierz w [data-model.md](data-model.md)); przy
  niezgodności — `fail` z instrukcją (np. „`db2` przyjmuje zapisy i nie replikuje, a inventory
  mówi `replica` — wykonaj krok 4 runbooka albo użyj `mysql_replication_reseed`”).
- **Alternatywy**: zawsze wykrywać rolę ze stanu bazy, ignorując inventory (ukrywa stan w
  bazie zamiast w repo — sprzeczne z zasadą I); playbook promowania (automatyzuje decyzję,
  którą spec świadomie zostawia człowiekowi).

## R9. Firewall (FR-016)

- **Decyzja**: fragment `/etc/nftables.d/mysql.nft` (kontrakt etapu 1
  `specs/001-etap1-fundament/contracts/firewall-dropin.md`) na węzłach `db`: `tcp dport 3306`
  z adresów `groups['web']` + `groups['db']` bez własnego adresu. Zgodne z tabelą architektury
  (`db1`: web1, web2, db2; `db2`: web1, web2, db1).

## R10. Regresja testu firewalla etapu 1 (FR-021)

- **Decyzja**: test US4.1/US4.2 etapu 1 przenoszony z portu 3306 na **9999/TCP** — port
  nieużywany w żadnym etapie (tabela architektury: 22, 80, 3306, 8404, 2224, 5405). Zmienna
  `us4_probe_port` w playbooku, adnotacja w tutorialu etapu 1 i w kontrakcie weryfikacji etapu 1.

## R11. Testy z węzłów WWW bez klienta bazy na stałe (FR-020)

- **Problem**: logowanie kontem `app` musi wyjść z `web1`/`web2`, a te węzły nie mają (i do
  etapu 3 nie potrzebują) klienta bazy.
- **Decyzja**: `ops` ma PyMySQL w venv Ansible (`requirements-ops.txt`, wersja przypięta, ta
  sama linia 1.1 co w Debianie). Playbook weryfikacyjny kopiuje czysto pythonowy pakiet
  `pymysql` z `ops` do katalogu tymczasowego na węźle WWW, uruchamia skrypt testowy
  (`playbooks/verify/files/mysql_probe.py`) z `PYTHONPATH` i sprząta w `always`. Na węzłach `db`
  używany jest systemowy `python3-pymysql`.
- **Alternatywy**: `mysql-client` na węzłach WWW (repozytorium Oracle na węzłach, które go nie
  potrzebują); sam test portu (nie dowodzi ograniczenia konta — US5.1/5.2).

## R12. Kolejność w `site.yml`

- **Decyzja**: `site.yml` = `preflight.yml` → `common.yml` → `db.yml`. `db.yml`: play 0
  (`hosts: db`, kontrola zgodności `mysql_replication/check.yml` na węzłach z zainstalowanym
  MySQL — przed jakąkolwiek zmianą konfiguracji, FR-018), play 1
  (`hosts: db`, rola `mysql`: repozytorium, pakiety, konfiguracja, firewall, konta i baza `app`
  **tylko na źródle**), play 2 (`hosts: db`, rola `mysql_replication`: kontrola zgodności,
  klon i replikacja **tylko na replice**). Konta istnieją na źródle, zanim replika spróbuje
  klonowania. Na replice rola nie wykonuje żadnych zapisów SQL poza klonem i konfiguracją
  replikacji (unikanie errant GTID).
