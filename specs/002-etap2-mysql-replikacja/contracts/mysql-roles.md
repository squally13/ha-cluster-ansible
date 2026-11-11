# Kontrakt: role `mysql` i `mysql_replication`

Zmienne i reguły: [data-model.md](../data-model.md). Decyzje: [research.md](../research.md).

## Rola `mysql` (play 1 w `playbooks/db.yml`, `hosts: db`, tag `mysql`)

**Wejście**: `mysql_server_id`, `mysql_role` (host_vars), zmienne `mysql_*` z `defaults/`,
hasła z Vaulta.

**Zadania (kolejność, pliki `tasks/`)**:

| Plik | Co | Tag | Na którym węźle |
|---|---|---|---|
| `assert.yml` | unikalne `mysql_server_id`; dokładnie jeden `source`; `mysql_role` ∈ {source, replica} | `mysql` | wszystkie `db` (`run_once` dla reguł grupowych) |
| `repo.yml` | klucz Oracle, plik `sources` z `Signed-By`, `apt_preferences` z dokładną wersją | `mysql`, `mysql-install` | wszystkie `db` |
| `install.yml` | debconf `root-pass` pusty; pakiety `mysql-server={{ mysql_version }}`, `python3-pymysql`; usługa `enabled` + `started` | `mysql`, `mysql-install` | wszystkie `db` |
| `config.yml` | `mysqld.cnf` (→ `Restart mysql`), `role.cnf` (→ `Apply mysql role settings`) | `mysql`, `mysql-config` | wszystkie `db` |
| `role_drift.yml` | po `flush_handlers`: `@@read_only`/`@@super_read_only` zgodne z rolą, przy dryfie → `Apply mysql role settings` | `mysql`, `mysql-config` | wszystkie `db` |
| `firewall.yml` | `/etc/nftables.d/mysql.nft` (→ `reload firewall` z roli `common`) | `mysql`, `firewall` | wszystkie `db` |
| `secure.yml` | usunięcie kont anonimowych, `root` spoza `localhost`, bazy `test` | `mysql`, `mysql-accounts` | **tylko `source`** |
| `accounts.yml` | konta `repl`, `clone`, `app` (hosty z inventory), baza `app` (`no_log`) | `mysql`, `mysql-accounts` | **tylko `source`** |

Kolejność w `main.yml`: `assert` → `repo` → `config` (szablony **przed** pakietem) → `install` → `meta: flush_handlers` (restart przed operacjami SQL) → `role_drift` → `firewall` → `secure` → `accounts` → `app`.

**Handlery**:

- `Restart mysql` — `systemd: state=restarted`, potem `wait_for` na port 3306 adresu węzła.
- `Apply mysql role settings` — `mysql_query`: `SET GLOBAL read_only`, `super_read_only`,
  `clone_valid_donor_list` zgodnie z `role.cnf` (bez restartu).

**Gwarancje**:

1. Wersja serwera = `mysql_version`; usługa `active` i `enabled`.
2. `role.cnf` na replice: `read_only=ON`, `super_read_only=ON` (od startu usługi); na źródle
   `OFF`.
3. Na replice rola `mysql` **nie wykonuje żadnych zapisów SQL** (brak errant GTID) — konta i baza
   `app` docierają replikacją.
4. Drugi przebieg: `changed=0` (konta z `update_password: on_create`; brak restartu bez zmiany
   pliku).
5. Każdy szablon z nagłówkiem „Zarządzane przez Ansible”, konfiguracja walidowana przed
   restartem.

## Rola `mysql_replication` (play 2 w `playbooks/db.yml`, `hosts: db`, tag `replication`)

**Wejście**: jak wyżej + `mysql_replication_reseed` (opcjonalnie, `-e`).

**Zadania**:

| Krok | Co | Gdzie |
|---|---|---|
| 1. Stan | `getreplica`, `user_schemas`, `gtid_executed` → fakty `mysql_replication_state` | wszystkie `db` |
| 2. Zgodność | macierz z [data-model.md](../data-model.md) → `fail` z instrukcją przy niezgodności | wszystkie `db` |
| 3. Klon | tylko replika pusta lub `reseed`: `CLONE INSTANCE FROM 'clone'@'<źródło>':3306 ... REQUIRE SSL` (`no_log`), potem `wait_for` na port i ponowny odczyt stanu | replika |
| 4. Replikacja | tylko gdy `is_replica == false`: `changereplication` (`primary_host` = adres źródła, `primary_auto_position: true`, `primary_ssl: true`, konto `repl`) + `startreplica` | replika |
| 5. Sprawdzenie | `getreplica` do skutku (≤ 60 s): `Replica_IO_Running: Yes`, `Replica_SQL_Running: Yes` | replika |

**Gwarancje**:

1. Działająca replikacja nie jest zatrzymywana, resetowana ani przekonfigurowywana (FR-010).
2. Klon nigdy nie nadpisuje węzła z danymi bez `mysql_replication_reseed` (FR-012).
3. Niezgodność repo ↔ stan kończy przebieg **przed** zmianą (FR-018).
4. Drugi przebieg: `changed=0` (zadania odczytu z `changed_when: false`).

## `playbooks/preflight.yml` (pierwszy import w `site.yml`)

`hosts: localhost`, `gather_facts: false`; `assert`, że `vault_mysql_repl_password`,
`vault_mysql_clone_password`, `vault_mysql_app_password` są zdefiniowane i niepuste
(`no_log`). Brak hasła do Vaulta → błąd Ansible przy odszyfrowaniu, zanim ruszy `common.yml`.

## Playbook `playbooks/db.yml`

```yaml
- name: Baza danych (MySQL)
  hosts: db
  become: true
  roles: [{ role: mysql, tags: [mysql] }]

- name: Replikacja
  hosts: db
  become: true
  roles: [{ role: mysql_replication, tags: [replication] }]
```

`site.yml`: `import_playbook` kolejno `preflight.yml`, `common.yml`, `db.yml`.
