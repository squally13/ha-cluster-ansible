# Kontrakt: playbook weryfikacyjny `playbooks/verify/stage2.yml`

Automatyzuje scenariusze US1–US5 ze [spec.md](../spec.md). Jak w etapie 1: nie należy do
`site.yml`; dane testowe i pliki tymczasowe są sprzątane w `always`, więc trwały stan węzłów
się nie zmienia.

## Wywołanie

```bash
# ops, admin, /vagrant
ansible-playbook playbooks/verify/stage2.yml             # wszystko
ansible-playbook playbooks/verify/stage2.yml --tags us2  # jedna historyjka
ansible-playbook playbooks/verify/stage1.yml playbooks/verify/stage2.yml  # regresja (SC-009)
```

Struktura: `stage2.yml` importuje `stage2/us1.yml` … `stage2/us5.yml` (tagi `us1`–`us5`).
Pomocnicze: `playbooks/verify/files/mysql_probe.py` (logowanie + zapytanie przez PyMySQL; wynik
`RESULT=<ok|denied|readonly|error> ...`) i `tcp_probe.py` z etapu 1.

## Testy i oczekiwane wyniki

| Tag | Scenariusz | Sprawdzenie | Wynik oczekiwany |
|---|---|---|---|
| `us1` | US1.1 | `systemctl is-active/is-enabled mysql`; `SELECT VERSION()` | `active`, `enabled`, `8.4.13` na `db1`, `db2` |
| `us1` | US1.2 | lista kont i baz | brak `''@%`, brak `root` poza `localhost`, brak `test`; `root@localhost` plugin `auth_socket` |
| `us1` | US1.3 | `@@server_id`, `@@gtid_mode`, `@@log_bin` | różne `server_id` > 0; `ON`; `1` |
| `us1` | US1.5 | `systemctl list-unit-files mysql.service` na `ops`, `lb`, `web` | brak jednostki |
| `us2` | US2.1 | `getreplica` na replice | `Replica_IO_Running: Yes`, `Replica_SQL_Running: Yes`, `Seconds_Behind_Source: 0` |
| `us2` | US2.2, SC-003 | `CREATE DATABASE verify_stage2`, `INSERT` znacznika czasu na źródle; odpytywanie repliki co 0,5 s | wiersz widoczny ≤ 5 s; czas zapisany w wyniku; `DROP DATABASE` w `always` |
| `us2` | US2.3 | `Source_Host`, `Auto_Position`, `Source_User`, `Source_SSL_Allowed` | adres źródła z inventory, `1`, `repl`, `Yes` |
| `us2` | US2.4 | `mysql_probe.py` z `web1` kontem `repl` na źródło | `RESULT=denied` |
| `us3` | US3.2 | `@@gtid_executed` repliki przed i po `site.yml` + `Replica_*` uptime | (test ręczny w quickstart — wymaga przebiegu `site.yml`) |
| `us4` | US4.1 | `mysql_probe.py` z `web1` kontem `app`: `INSERT` na replice | `RESULT=readonly` |
| `us4` | US4.2 | `root` przez gniazdo na replice: `CREATE DATABASE x` | błąd `--super-read-only` |
| `us4` | US4.3 | `@@read_only`, `@@super_read_only` na replice; `role.cnf` zawiera oba | `1`, `1`, obecne |
| `us5` | US5.1 | `mysql_probe.py` z `web1` i `web2` kontem `app` na źródło: `CREATE TABLE`/`DROP TABLE` w `app`; `SHOW GRANTS` | `RESULT=ok`; uprawnienia tylko do `app.*` |
| `us5` | US5.2 | `mysql_probe.py` z **`db2`** kontem `app` na `db1` | `RESULT=denied` |
| `us5` | US5.3/5.4 | `tcp_probe.py` → `db1:3306` i `db2:3306` z `lb1`, `ops` (timeout 3 s) oraz z `web1`, `web2`, drugiego `db` | `timeout` / `connected` |

Na węzłach WWW `pymysql` jest kopiowany z venv `ops` do `/tmp/verify-pymysql-<losowe>` i usuwany
w `always` (research R11).

## Zmiana w weryfikacji etapu 1 (FR-021)

`playbooks/verify/stage1/us4.yml`: tymczasowy nasłuch i sonda na porcie **9999** zamiast 3306
(`us4_probe_port: 9999`). Oczekiwane wyniki bez zmian (`web1 → db1:9999` timeout, lokalnie
connected). Kontrakt `specs/001-etap1-fundament/contracts/verification.md` i tutorial etapu 1
dostają adnotację o zmianie.

## Testy ręczne (quickstart)

US2.5 (restart repliki i nadrabianie), US3 (dwa przebiegi `site.yml` i `--check --diff` z
zapisami w międzyczasie), US1.4 (zły szablon), SC-010 (odtworzenie samego `db2`), US6 (runbook
w obie strony), edge case brak `.vault_pass`.
