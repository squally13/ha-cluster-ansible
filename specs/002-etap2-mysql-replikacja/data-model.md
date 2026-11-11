# Data Model: Etap 2 — Baza danych z replikacją source → replica (GTID)

**Data**: 2026-11-11 | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

Model opisuje stan deklarowany w repozytorium (inventory, zmienne, Vault) i stan obserwowany na
węzłach `db`, który rola porównuje z deklaracją.

## Encje deklarowane (repozytorium)

### Węzeł bazy (`host_vars/db1.yml`, `host_vars/db2.yml`)

| Pole | Typ | Przykład | Reguły |
|---|---|---|---|
| `mysql_server_id` | int | `1` / `2` | > 0, unikalny w grupie `db` (assert w roli) |
| `mysql_role` | enum | `source` / `replica` | dokładnie **jeden** host `db` ma `source` (assert, `run_once`) |
| `ansible_host` | IPv4 | `192.168.56.31` | z `hosts.yml` (etap 1); adres nasłuchu bazy |
| `vagrant_memory` | int (MB) | `1536` | z `hosts.yml`; podstawa doboru pamięci bazy |

Pochodne (wyliczane, nie wpisywane): `mysql_replication_source_host` = jedyny host `db` z
`mysql_role == 'source'`; `mysql_db_peer_addresses` = adresy `groups['db']`;
`mysql_web_addresses` = adresy `groups['web']`.

### Ustawienia grupy (`roles/mysql/defaults/main.yml`, nadpisywane w `group_vars/db.yml`)

| Zmienna | Domyślnie | Uwagi |
|---|---|---|
| `mysql_version` | `8.4.13-1debian13` | dokładne przypięcie (R1, ADR 0010) |
| `mysql_apt_component` | `mysql-8.4-lts` | |
| `mysql_innodb_buffer_pool_size` | `256M` | FR-006 |
| `mysql_max_connections` | `100` | FR-006 |
| `mysql_binlog_expire_logs_seconds` | `604800` | FR-007 (7 dni) |
| `mysql_app_database` | `app` | FR-014 |
| `mysql_app_user` | `app` | FR-014 |
| `mysql_repl_user` / `mysql_clone_user` | `repl` / `clone` | R5, R6 |
| `mysql_replication_reseed` | `""` | tylko z `-e`; nazwa hosta, który wolno zasilić mimo danych (R8) |

### Sekrety (`group_vars/all/vault.yml`, zaszyfrowany)

| Zmienna Vault | Zmienna jawna | Użycie |
|---|---|---|
| `vault_mysql_repl_password` | `mysql_repl_password` | konto `repl` |
| `vault_mysql_clone_password` | `mysql_clone_password` | konto `clone` |
| `vault_mysql_app_password` | `mysql_app_password` | konto `app` (etap 3: aplikacja) |

Brak hasła `root` — `auth_socket` (R3). Reguła: każda zmienna `vault_*` istnieje (preflight).

## Encje w bazie (tworzone wyłącznie na źródle, replikowane)

| Konto | Hosty (`'user'@'host'`) | Uprawnienia | Hasło |
|---|---|---|---|
| `root` | `localhost` | wszystkie | `auth_socket` (bez hasła) |
| `repl` | każdy adres z `groups['db']` | `REPLICATION SLAVE ON *.*` | Vault |
| `clone` | każdy adres z `groups['db']` | `BACKUP_ADMIN ON *.*` | Vault |
| `app` | każdy adres z `groups['web']` | `ALL ON app.*` | Vault |

Usuwane („secure installation”): konta z pustą nazwą, `root` z hostów innych niż `localhost`,
baza `test`. Baza `app`: `utf8mb4`, pusta (schemat w etapie 3).

## Stan obserwowany węzła

| Właściwość | Źródło | Znaczenie |
|---|---|---|
| `is_replica` | `mysql_replication mode=getreplica` → `Is_Replica` | replikacja skonfigurowana |
| `replica_source_host` | `Source_Host` | dokąd replikuje |
| `replica_errors` | `Last_IO_Error`, `Last_SQL_Error` | niepuste = replikacja stoi |
| `user_schemas` | `information_schema.SCHEMATA` bez `mysql`, `sys`, `information_schema`, `performance_schema` | dane użytkownika |
| `gtid_executed` | `@@GLOBAL.gtid_executed` | historia transakcji GTID |
| `read_only` / `super_read_only` | zmienne globalne | tryb tylko do odczytu |

**Węzeł „pusty”** = `is_replica == false` **i** `user_schemas == []` **i** `gtid_executed == ''`.
Tylko pusty węzeł (albo jawnie wskazany `mysql_replication_reseed`) może zostać zasilony klonem.

## Macierz zgodności (FR-018, kontrola przed zmianami w roli `mysql_replication`)

| `mysql_role` (repo) | Stan węzła | Akcja |
|---|---|---|
| `source` | `is_replica == false` | OK — dalej |
| `source` | `is_replica == true` | **fail**: „węzeł nadal replikuje — wykonaj krok promowania z runbooka (STOP/RESET REPLICA)” |
| `replica` | pusty | zasil klonem ze źródła → `changereplication` → `startreplica` |
| `replica` | `is_replica == true`, `Source_Host` = adres źródła z repo, brak błędów | OK — nic nie rób |
| `replica` | `is_replica == true`, błąd w `Last_*_Error` | **fail** z treścią błędu (FR-013), bez resetu |
| `replica` | `is_replica == true`, `Source_Host` ≠ źródło z repo | **fail**: „replikuje z innego źródła niż w repo” (chyba że `reseed`) |
| `replica` | `is_replica == false`, **niepusty** | **fail**: „węzeł ma dane i nie replikuje — czy był promowany? zaktualizuj inventory albo `-e mysql_replication_reseed=<host>`” |
| `replica` | dowolny, host == `mysql_replication_reseed` | klon ze źródła (nadpisuje dane) → replikacja |

## Przejścia stanów węzła bazy

```text
[zainstalowany, pusty] --rola=source--> [SOURCE: zapisy, konta, baza app]
[zainstalowany, pusty] --rola=replica, klon--> [SKLONOWANY] --changereplication+start--> [REPLICA]
[REPLICA] --runbook: STOP/RESET REPLICA ALL, read_only OFF--> [ODŁĄCZONY, zapisywalny]
[ODŁĄCZONY] --repo: mysql_role=source + site.yml--> [SOURCE]
[dawny SOURCE, z danymi] --repo: mysql_role=replica + -e reseed--> [SKLONOWANY] --> [REPLICA]
```

## Reguły firewalla (fragment `/etc/nftables.d/mysql.nft`)

| Węzeł | Źródła 3306/TCP |
|---|---|
| `db1` | `groups['web']` + `groups['db']` bez `db1` → 192.168.56.21, .22, .32 |
| `db2` | `groups['web']` + `groups['db']` bez `db2` → 192.168.56.21, .22, .31 |
