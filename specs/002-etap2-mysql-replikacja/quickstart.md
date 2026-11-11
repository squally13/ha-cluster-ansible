# Quickstart: walidacja etapu 2

Przewodnik sprawdzający, że etap 2 działa od początku do końca. Szczegóły testów:
[contracts/verification.md](contracts/verification.md); reguły stanu:
[data-model.md](data-model.md). Hosty: **[PS]** PowerShell w repo, **[ops]** `admin@ops` w
`/vagrant`, **[dbN]** `vagrant ssh dbN` + `sudo -i`.

## Wymagania wstępne

- Lab z etapu 1 (lub `vagrant up` od zera), gałąź `002-etap2-mysql-replikacja`.
- Vault: [ops] `tools/init-vault.sh` (jeśli nie masz hasła autora) — tworzy `.vault_pass` i
  `inventories/lab/group_vars/all/vault.yml`. Sprawdzenie: `ansible-vault view
  inventories/lab/group_vars/all/vault.yml` pokazuje 3 zmienne `vault_mysql_*`.
- `ansible-galaxy collection install -r requirements.yml` na `ops` (nowa kolekcja
  `ansible.mysql`) — robi to bootstrap przy `vagrant up`.

## 1. Pierwszy przebieg i weryfikacja (US1, US2, US4, US5)

[ops]:

```bash
ansible-playbook playbooks/site.yml
ansible-playbook playbooks/verify/stage1.yml playbooks/verify/stage2.yml
```

Oczekiwane: przebieg 7/7 `failed=0 unreachable=0`; weryfikacja obu etapów `failed=0` (SC-009);
w wyniku `us2` czas widoczności wiersza ≤ 5 s (SC-003).

## 2. Idempotencja z zapisami w międzyczasie (US3, SC-002)

[db1]: `mysql -e "CREATE DATABASE IF NOT EXISTS t; CREATE TABLE IF NOT EXISTS t.x (i INT); INSERT INTO t.x VALUES (1);"`
[db2]: `mysql -e "SELECT @@gtid_executed; SHOW REPLICA STATUS\G" | grep -E 'gtid|Running:'` — zapisz.

[ops]:

```bash
ansible-playbook playbooks/site.yml                 # przebieg 2
ansible-playbook playbooks/site.yml --check --diff  # US3.3
```

Oczekiwane: 7/7 `changed=0`; `--check --diff` bez różnic; na `db2` `gtid_executed` ⊇ wartość
sprzed przebiegu, wątki `Yes`, `t.x` ma wiersz. Sprzątanie: [db1] `mysql -e "DROP DATABASE t"`.

## 3. Restart repliki (US2.5)

[PS] `vagrant reload db2`; w tym czasie [db1] `mysql -e "CREATE DATABASE r; DROP DATABASE r;"`.
[db2] po starcie: `SHOW REPLICA STATUS\G` → oba wątki `Yes`, `Seconds_Behind_Source: 0`,
`gtid_executed` zawiera transakcje `r`.

## 4. Zły szablon (US1.4)

Dopisz `BlednaOpcja = 1` w `roles/mysql/templates/mysqld.cnf.j2`; [ops]
`ansible-playbook playbooks/site.yml --tags mysql-config` → błąd walidacji, `db1`/`db2` nadal
`active` i przyjmują połączenia. Cofnij zmianę → `changed=0`.

## 5. Odtworzenie samej repliki przy danych na źródle (SC-010)

[db1]: utwórz dane testowe jak w kroku 2. [PS] `vagrant destroy -f db2; vagrant up db2`.
[ops] `ansible-playbook playbooks/site.yml` → na `db2` klon i replikacja; [db2] `t.x` ma
wiersz, wątki `Yes`. Drugi przebieg `changed=0`.

## 6. Ochrona przed nadpisaniem i niezgodnością (FR-012, FR-018)

[db2] `mysql -e "STOP REPLICA; RESET REPLICA ALL;"` (symulacja promowania bez zmiany repo).
[ops] `ansible-playbook playbooks/site.yml --tags replication` → `fail` „węzeł ma dane i nie
replikuje…”, brak zmian na `db2`. Przywrócenie: `-e mysql_replication_reseed=db2`.

## 7. Runbook promowania w obie strony (US6, SC-007, SC-011)

Postępuj wg `docs/runbooks/mysql-promote-replica.md`:

1. Zapis kontrolny na `db1`, [PS] `vagrant halt db1`.
2. Runbook: zrzut na `db2`, promowanie, zmiana `mysql_role` w `host_vars`, `site.yml --limit 'all:!db1'`.
   Oczekiwane: `db2` przyjmuje zapis kontem `app` z `web1`; zapis kontrolny jest na `db2`;
   drugi przebieg `changed=0`; czas od startu runbooka ≤ 10 min (SC-007).
3. [PS] `vagrant up db1`; [ops] `site.yml -e mysql_replication_reseed=db1` → `db1` jest repliką
   `db2`, ma zapisy wykonane na `db2` po promowaniu.
4. Ten sam runbook w drugą stronę → układ wyjściowy; `verify/stage2.yml` zielony.

Wyniki (czasy, zapisy kontrolne) → `docs/notes.md`.

## 8. Brak hasła do Vaulta (edge case)

[ops] `ANSIBLE_VAULT_PASSWORD_FILE= ansible-playbook playbooks/site.yml` → błąd odszyfrowania w
`preflight.yml`, `PLAY RECAP` bez zmian na węzłach.

## 9. Zamknięcie etapu (FR-022, konstytucja)

3× z rzędu: [PS] `vagrant destroy -f; vagrant up`, [ops] `site.yml` ×2, `--check --diff`,
weryfikacja etapów 1 i 2. Oczekiwane jak w etapie 1 + replikacja działająca po każdym
odtworzeniu (SC-001). Czas SC-006 → ADR 0002. `git log -p | grep -iE 'password|haslo'` →
tylko odwołania do `vault_*` (SC-008).
