# Quickstart: walidacja etapu 1 — Fundament

Przewodnik walidacyjny: jak od zera dojść do środowiska etapu 1 i udowodnić, że spełnia
scenariusze akceptacyjne ze [spec.md](spec.md). Szczegóły testów automatycznych:
[contracts/verification.md](contracts/verification.md). To nie jest jeszcze docelowy tutorial
z `docs/` (powstaje w implementacji), ale ma ten sam układ: co → komenda → oczekiwany wynik.

## Wymagania wstępne (host Windows)

| Element | Wersja | Sprawdzenie | Oczekiwany wynik |
|---|---|---|---|
| RAM hosta | ≥ 16 GB | Menedżer zadań | ≥ 16 GB |
| VirtualBox | 7.x (dokładna wersja w ADR 0002) | `VBoxManage --version` | `7.x.y` |
| Vagrant | 2.4.x | `vagrant --version` | `Vagrant 2.4.x` |
| OpenSSH (Windows) | wbudowany | `ssh -V` | `OpenSSH_for_Windows_...` |
| Git | dowolna aktualna | `git config core.autocrlf` | `false` lub `input` (repo ma `.gitattributes` z LF) |
| Repo | na NTFS | ścieżka `C:\...` | **nie** `\\wsl$\...` (R1) |

## 1. Odtworzenie od zera (US1, SC-001)

```powershell
# PowerShell, w katalogu repo
vagrant destroy -f
vagrant up                        # tworzy 7 maszyn; przy pierwszym razie generuje .lab\ssh\id_ed25519
```

Oczekiwany wynik: `vagrant status` → 7 maszyn `running (virtualbox)`; plik `.lab\ssh\id_ed25519`
istnieje; `git status` go nie pokazuje.

## 2. Pierwszy i drugi przebieg (US1.1, US2.1, SC-002)

```powershell
ssh -i .lab\ssh\id_ed25519 admin@192.168.56.5   # albo: vagrant ssh ops, potem sudo -iu admin
```

```bash
# na ops, jako admin
cd /vagrant
ansible all -m ping                              # 7× "pong"
ansible-playbook playbooks/site.yml              # przebieg 1
ansible-playbook playbooks/site.yml              # przebieg 2
```

Oczekiwany wynik: przebieg 1 — `failed=0 unreachable=0` dla 7 hostów; przebieg 2 — dodatkowo
`changed=0` dla 7 hostów. Oba PLAY RECAP kopiujesz do opisu PR. Zmierz czas od `vagrant up` do
końca przebiegu 1 (SC-003: ≤ 30 min).

```bash
ansible-playbook playbooks/site.yml --check --diff   # US2.2: brak różnic
```

## 3. Testy automatyczne (US1, US3, US4, US5)

```bash
ansible-playbook playbooks/verify/stage1.yml
```

Oczekiwany wynik: wszystkie zadania `ok`, `failed=0`. Najważniejsze linie:
`web1 → db1:3306 RESULT=timeout`, `db1 lokalnie RESULT=connected`, `web1 → db1:22 RESULT=timeout`.

## 4. Testy ręczne z hosta

| Scenariusz | Komenda (PowerShell na hoście) | Oczekiwany wynik |
|---|---|---|
| US4.4 host → ops | `ssh -i .lab\ssh\id_ed25519 admin@192.168.56.5 hostname` | `ops` |
| US4.4 host → inny węzeł | `ssh -o ConnectTimeout=5 -i .lab\ssh\id_ed25519 admin@192.168.56.31` | `Connection timed out` |
| US4.6 kanał zarządzania | `vagrant ssh db1 -c hostname`; `vagrant halt web2; vagrant up web2` | `db1`; maszyna zatrzymana i uruchomiona bez błędów |
| US4.5 trwałość po restarcie | `vagrant reload db1`, potem z ops: `ansible db1 -b -m command -a "nft list chain inet filter input"` | `policy drop`, reguła SSH z 192.168.56.5 |
| US3.5 zły szablon SSH | wprowadź błąd w szablonie `sshd_config.j2`, `ansible-playbook playbooks/site.yml --tags ssh` | zadanie `failed` z błędem walidacji `sshd -t`; nadal możesz się zalogować; po cofnięciu błędu `changed=0` |
| US2.3 dryf | `vagrant ssh lb1 -c "sudo sed -i '1i # dryf' /etc/ssh/sshd_config"`, potem `site.yml` | `changed=1` na `lb1`, kolejny przebieg `changed=0` |
| US5.2 zegar | `vagrant ssh web1 -c "sudo date -s '-2 min'"`, odczekaj ≤ 5 min, `chronyc tracking` | \|System time\| < 0,5 s |
| US5.4 sygnał restartu | `ansible all -b -m command -a "needrestart -b -k"` (sprawdzane też automatycznie w `--tags us5`) | kod 0 i linia `NEEDRESTART-KSTA: 1` (restart niewymagany) lub 2/3 (wymagany); węzeł nie restartuje się sam |
| US5.4 symulacja (opcjonalnie) | na `web1`: instalacja dodatkowego pakietu jądra, potem `needrestart -b -k`; na koniec `vagrant destroy -f web1 && vagrant up web1` i `site.yml --limit web1` | `NEEDRESTART-KSTA: 2` lub `3`; `uptime` pokazuje, że nie było restartu |

## 5. Lint i CI (US6, SC-007)

```bash
pre-commit run --all-files     # lokalnie: wszystkie hooki "Passed"
```

Wypchnij gałąź z celowym błędem (np. zła indentacja w `roles/common/tasks/main.yml`):
oczekiwany wynik — czerwony job `lint` w GitHub Actions ze wskazaniem pliku i linii; merge PR
zablokowany. Po poprawce job zielony.

## 6. Zamknięcie etapu (konstytucja: definicja ukończenia)

- [ ] Kroki 1–2 wykonane 3 razy z rzędu bez błędów (SC-001).
- [ ] Krok 3 zielony; kroki z tabeli 4 wykonane.
- [ ] ADR-y z [plan.md](plan.md#adr-y-do-napisania-w-etapie-1) w `docs/adr/`.
- [ ] Tutorial etapu w `docs/` i wpisy w `docs/notes.md`.
- [ ] PR z PLAY RECAP obu przebiegów, linkami do ADR i Issues; lint zielony.
