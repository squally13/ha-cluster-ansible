# Etap 1 — Fundament

Tutorial od pustego hosta Windows do 7 węzłów Debian 13 z bezpieczną konfiguracją bazową.
Każdy krok: **Co** → **Dlaczego** → **Komenda** (z miejscem uruchomienia) → **Weryfikacja** →
**Typowe problemy**.

Oznaczenia miejsc uruchomienia:

- **[PS]** — PowerShell na hoście Windows, w katalogu repo (`C:\Users\<user>\projects\ha-homelab`);
- **[WSL]** — terminal WSL w katalogu `/mnt/c/Users/<user>/projects/ha-homelab`;
- **[ops]** — węzeł `ops`, konto `admin`, katalog `/vagrant`.

## Wymagania

| Element | Wersja | Sprawdzenie [PS] | Oczekiwany wynik |
|---|---|---|---|
| RAM hosta | ≥ 16 GB (lab zużywa ~7 GB) | Menedżer zadań → Wydajność | ≥ 16 GB |
| Wolne miejsce | ≥ 25 GB | `Get-PSDrive C` | ≥ 25 GB wolne |
| VirtualBox | 7.x (sprawdzone: 7.2.16) | `& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" --version` | `7.x.y` |
| Vagrant | 2.4.x | `vagrant --version` | `Vagrant 2.4.x` |
| OpenSSH | wbudowany w Windows 10/11 | `ssh -V` | `OpenSSH_for_Windows_...` |
| Git | aktualny | `git --version` | `git version 2.x` |
| WSL (do lintu) | Python ≥ 3.12 | [WSL] `python3 --version` | `Python 3.12+` |

Wersje używane w etapie (przypięte w repo): `bento/debian-13` `202510.26.0`, `ansible-core`
2.21.6, `ansible.posix` 2.2.2, `community.general` 14.0.0, `ansible-lint` 26.11.0, `yamllint`
1.38.0 — uzasadnienie w [ADR 0001](../adr/0001-debian-13.md) i `docs/notes.md`.

---

## Krok 1. Repozytorium na NTFS z końcami linii LF

**Co**: sklonuj repo na dysk Windows (nie do WSL).

**Dlaczego**: folder współdzielony VirtualBoxa nie obsługuje ścieżek `\\wsl$\...`, a skrypty z
CRLF nie działają na Linuksie ([ADR 0002](../adr/0002-vagrant-virtualbox-windows.md)).

**Komenda** [PS]:

```powershell
mkdir $HOME\projects -Force; cd $HOME\projects
git clone https://github.com/<konto>/ha-homelab.git
cd ha-homelab
git config core.autocrlf false
```

**Weryfikacja** [WSL]: `file vagrant/bootstrap-node.sh` → `... ASCII text` / `UTF-8 text`
(**bez** `with CRLF line terminators`).

**Typowe problemy**:

- *Objaw*: `bootstrap-node.sh: line 1: $'\r': command not found` podczas `vagrant up`.
  *Przyczyna*: CRLF z `core.autocrlf=true` sprzed klonowania. *Naprawa*:
  `git config core.autocrlf false; git rm -r --cached .; git reset --hard`.

## Krok 2. Narzędzia lintu i hooki przed commitem

**Co**: zainstaluj `yamllint`, `ansible-lint`, `pre-commit` i hooki Git.

**Dlaczego**: kod musi przechodzić lint przed każdym commitem (konstytucja, zasada III).
`ansible-lint` nie działa natywnie na Windowsie, dlatego robimy to w WSL — **commity wykonuj
z WSL** (Git for Windows nie uruchomi hooka).

**Komenda** [WSL]:

```bash
python3 -m venv ~/.venvs/ha-homelab
source ~/.venvs/ha-homelab/bin/activate
pip install -r requirements-dev.txt
ansible-galaxy collection install -r requirements.yml
pre-commit install
pre-commit run --all-files
```

**Weryfikacja**: wszystkie hooki `Passed` (check yaml, fix end of files, trim trailing
whitespace, mixed line ending, yamllint, ansible-lint).

**Typowe problemy**:

- *Objaw*: `Ansible is being run in a world writable directory ... ignoring it as an ansible.cfg
  source` w WSL. *Przyczyna*: `/mnt/c` jest montowany jako `0777`. Dla lintu to bez znaczenia;
  jeśli uruchamiasz `ansible-playbook --syntax-check` w WSL, ustaw
  `export ANSIBLE_CONFIG=$PWD/ansible.cfg`. Playbooki uruchamiamy na `ops`, gdzie problem nie
  występuje (krok 4).

## Krok 3. Utworzenie maszyn

**Co**: `vagrant up` tworzy 7 maszyn z `inventories/lab/hosts.yml`, generuje parę kluczy labu i
wykonuje bootstrap.

**Dlaczego**: lista maszyn ma jedno źródło ([ADR 0009](../adr/0009-jedno-zrodlo-listy-maszyn.md));
bootstrap tworzy konto `admin` z kluczem labu, żeby Ansible mógł się zalogować bez konta
`vagrant` ([ADR 0005](../adr/0005-bootstrap-klucze-labu.md)).

**Komenda** [PS]:

```powershell
Measure-Command { vagrant up | Out-Default }   # mierzy czas (SC-003)
```

**Weryfikacja** [PS]:

```powershell
vagrant status                 # 7× "running (virtualbox)"
Test-Path .lab\ssh\id_ed25519  # True
git status --short             # pusto — .lab\ jest ignorowany
```

**Typowe problemy**:

- *Objaw*: VM startuje bardzo wolno lub zawiesza się; w logu VirtualBoxa „NEM”/żółwik w oknie VM.
  *Przyczyna*: aktywny Hyper-V (WSL2, Docker Desktop) — VirtualBox działa przez Windows
  Hypervisor Platform. *Sprawdzenie*: `bcdedit /enum | findstr hypervisorlaunchtype`.
  *Naprawa*: jeśli czas > 30 min — `bcdedit /set hypervisorlaunchtype off` (PowerShell jako
  administrator) i restart; cofnięcie: `... auto`. Wyłącza to WSL2 na czas pracy z labem.
- *Objaw*: `VBoxManage: error: ... host-only adapter` / `The IP address configured for the
  host-only network is not within the allowed ranges`. *Naprawa*: sieć 192.168.56.0/24 jest
  domyślnie dozwolona; jeśli masz własny `C:\Users\<user>\.config\VirtualBox\networks.conf`,
  dodaj linię `* 192.168.56.0/21`.
- *Objaw*: `mount: unknown filesystem type 'vboxsf'` na `ops`. *Przyczyna*: obraz bez dodatków
  gościa. *Naprawa*: sprawdź wersję boxa w `Vagrantfile` (`BOX_VERSION`) i `docs/notes.md`.
- *Objaw*: `Nie udało się wygenerować klucza labu`. *Przyczyna*: brak `ssh-keygen` w PATH.
  *Naprawa*: Ustawienia → Aplikacje → Funkcje opcjonalne → „Klient OpenSSH”.

## Krok 4. Łączność Ansible z `ops`

**Co**: zaloguj się na `ops` jako `admin` i sprawdź, że Ansible widzi 7 hostów.

**Dlaczego**: `ops` to węzeł sterujący ([ADR 0003](../adr/0003-ops-wezel-sterujacy.md)); repo
jest na nim w `/vagrant` z uprawnieniami 755/644, więc `ansible.cfg` jest czytany
([ADR 0008](../adr/0008-folder-wspoldzielony-ops.md)).

**Komenda** [PS]:

```powershell
ssh -i .lab\ssh\id_ed25519 admin@192.168.56.5
# albo: vagrant ssh ops, potem: sudo -iu admin
```

[ops]:

```bash
ansible all -m ping
ansible-config dump --only-changed
```

**Weryfikacja**: 7× `"ping": "pong"`; w `ansible-config dump` widać `DEFAULT_HOST_LIST`,
`DEFAULT_REMOTE_USER(/vagrant/ansible.cfg) = admin` itd. — bez ostrzeżenia o katalogu
zapisywalnym dla wszystkich.

**Typowe problemy**:

- *Objaw*: z hosta `ssh admin@192.168.56.5` → `Connection timed out` po pierwszym `site.yml`.
  *Przyczyna*: adres hosta w sieci host-only jest inny niż 192.168.56.1, a firewall i `AllowUsers`
  na `ops` dopuszczają tylko `common_ssh_host_address`. *Sprawdzenie* [PS]: `ipconfig` → karta
  „VirtualBox Host-Only Network” → „IPv4 Address”. *Naprawa*: wpisz ten adres w
  `inventories/lab/group_vars/all/main.yml`, wejdź przez `vagrant ssh ops` + `sudo -iu admin` i
  uruchom `ansible-playbook playbooks/site.yml --limit ops`.
- *Objaw*: przy pierwszym połączeniu, po `Warning: Permanently added '192.168.56.5'`, terminal
  nie pokazuje znaku zachęty. *Naprawa*: przerwij (Ctrl+C) i połącz się ponownie — klucz hosta
  jest już zapisany; alternatywnie `vagrant ssh ops` + `sudo -iu admin`.
- *Objaw*: `[WARNING]: Found both group and host with same name: ops`. Celowe (grupa `ops` z
  hostem `ops`) — ostrzeżenie nieszkodliwe.
- *Objaw*: `UNREACHABLE ... Permission denied (publickey)`. *Sprawdzenie* [ops]:
  `ls -l ~/.ssh/id_ed25519` → `-rw------- admin admin`. *Naprawa*: `vagrant provision ops` [PS].

## Krok 5. Pierwszy przebieg konfiguracji (US1)

**Co**: rola `common` konfiguruje wszystkie węzły: pakiety, konto `admin`, nazwę hosta i
`/etc/hosts`, czas, firewall, SSH, aktualizacje.

**Dlaczego**: cały stan bazowy jest kodem (zasada I). Kolejność zadań (firewall przed SSH,
restarty w handlerach na końcu) wyklucza utratę dostępu w trakcie przebiegu (FR-018).

**Komenda** [ops]:

```bash
time ansible-playbook playbooks/site.yml
```

**Weryfikacja**: `PLAY RECAP` — `failed=0 unreachable=0` dla 7 hostów. Czas `vagrant up` +
ten przebieg ≤ 30 min (SC-003) — zapisz w [ADR 0002](../adr/0002-vagrant-virtualbox-windows.md).

```bash
ansible-playbook playbooks/verify/stage1.yml --tags us1
ansible web1 -a "getent hosts db1"     # 192.168.56.31   db1
```

**Typowe problemy**:

- *Objaw*: `getent hosts $(hostname)` zwraca `127.0.1.1`. *Przyczyna*: `config.vm.hostname` w
  `Vagrantfile` albo ręczna edycja. *Naprawa*: usuń `config.vm.hostname`, uruchom `site.yml`
  ([ADR 0009](../adr/0009-jedno-zrodlo-listy-maszyn.md)).
- *Objaw*: przebieg przerwany (restart węzła, `apt` nie może pobrać pakietów —
  `Failed to fetch ... deb.debian.org`). *Sprawdzenie* [ops]:
  `ansible <host> -a "curl -sI https://deb.debian.org"`. *Naprawa*: po przywróceniu sieci
  ponownie `ansible-playbook playbooks/site.yml` — rola jest idempotentna i dokańcza
  konfigurację; jednorazowa pełna aktualizacja wykona się, bo znacznik
  `/var/lib/ha-homelab/initial-upgrade.done` powstaje dopiero po jej sukcesie.
- *Objaw*: po przerwanym przebiegu pliki (`sshd_config`, `nftables.conf`, `chrony.conf`) są
  już nowe, ale usługi działają na starej konfiguracji, a kolejny przebieg nic nie zmienia.
  *Przyczyna*: handlery (restart/przeładowanie) nie wykonały się po błędzie, a ponowny przebieg
  ich nie wywoła, bo pliki są aktualne. *Zapobieganie*: `force_handlers = True` w `ansible.cfg`
  — działa tylko, gdy `ansible.cfg` jest czytany (krok 4). *Naprawa*: `vagrant reload <węzeł>`
  albo odtworzenie od zera.
- *Objaw*: `dpkg: error processing package grub-pc` / `You must correct your GRUB install
  devices`. *Przyczyna*: obraz pamięta dysk GRUB-a z maszyny budującej. *Naprawa*: rola ustawia
  `grub-pc/install_devices` przed pierwszą aktualizacją (`common_grub_install_devices`,
  domyślnie `/dev/sda`); jeśli dysk VM ma inną nazwę — nadpisz zmienną w `group_vars`.
- *Objaw*: `Unable to start service apt-daily.timer`. *Przyczyna*: usługi `apt-daily*`
  zamaskowane w obrazie; rola je odmaskowuje — sprawdź, czy nie zmieniono `updates.yml`.

## Krok 6. Test idempotencji (US2)

**Co**: drugi przebieg nie może niczego zmienić; tryb sprawdzania nie pokazuje różnic; ręczny
dryf jest cofany.

**Dlaczego**: idempotencja jest niepodważalna (zasada II, FR-013).

**Komenda** [ops]:

```bash
ansible-playbook playbooks/site.yml                 # przebieg 2
ansible-playbook playbooks/site.yml --check --diff  # US2.2
```

**Weryfikacja**: przebieg 2 — `changed=0 failed=0` dla 7/7 hostów; `--check --diff` — brak
sekcji diff i `changed=0`.

Test dryfu (US2.3) [PS]:

```powershell
vagrant ssh lb1 -c "sudo sed -i '1i # dryf' /etc/ssh/sshd_config"
```

[ops]: `ansible-playbook playbooks/site.yml` → `lb1 changed=2` (zadanie „Wygeneruj konfigurację
serwera SSH” + handler `Restart ssh`); kolejny przebieg → `changed=0` na 7 hostach.

**Typowe problemy**:

- *Objaw*: przebieg 2 ma `changed>0`. *Sprawdzenie*: `ansible-playbook playbooks/site.yml -v |
  grep -B3 "changed:"` — które zadanie. Typowe przyczyny: zadanie `command` bez `changed_when`,
  szablon z niedeterministyczną treścią (np. data), `apt` z odświeżeniem cache. Przyczynę i
  poprawkę zapisz w `docs/notes.md`.

## Krok 7. Bezpieczny dostęp SSH (US3)

**Co**: `admin` loguje się tylko kluczem labu i tylko z dozwolonego źródła; hasła, `root` i
`vagrant` z sieci labu są odrzucane.

**Dlaczego**: [ADR 0003](../adr/0003-ops-wezel-sterujacy.md),
[ADR 0005](../adr/0005-bootstrap-klucze-labu.md), [ADR 0006](../adr/0006-konto-vagrant.md).

**Komenda** [ops]:

```bash
ansible-playbook playbooks/verify/stage1.yml --tags us3
```

**Weryfikacja**: `failed=0`. Test sprawdza na 7/7 węzłach efektywną konfigurację (`sshd -T`):
`passwordauthentication no`, `kbdinteractiveauthentication no`, `permitrootlogin no`, właściwe
`allowusers`; oraz z `ops` próby logowania hasłem (`Permission denied (publickey)`), jako `root`
i jako `vagrant` — wszystkie odrzucone.

Zły szablon (US3.5) [ops]: dopisz na końcu `roles/common/templates/sshd_config.j2` linię
`BlednaOpcja tak`, uruchom `ansible-playbook playbooks/site.yml --tags ssh`.
Oczekiwane: zadanie „Wygeneruj konfigurację serwera SSH” `FAILED` z komunikatem
`Bad configuration option: BlednaOpcja` (walidacja `sshd -t`); [PS]
`ssh -i .lab\ssh\id_ed25519 admin@192.168.56.5 hostname` → `ops` (dostęp działa). Usuń linię,
uruchom `site.yml` → `changed=0`.

**Typowe problemy**:

- *Objaw*: po zmianie SSH brak dostępu do węzła. *Naprawa*: `vagrant ssh <węzeł>` (kanał NAT
  zawsze otwarty — [ADR 0006](../adr/0006-konto-vagrant.md)), `sudo sshd -T | grep allowusers`.

## Krok 8. Firewall z domyślną odmową (US4)

**Co**: polityka `drop`; otwarte tylko SSH z `ops`, SSH z hosta do `ops` i kanał Vagranta.

**Dlaczego**: [ADR 0004](../adr/0004-firewall-nftables-porty-per-etap.md). Kolejne etapy otwierają
porty fragmentami w `/etc/nftables.d/` (kontrakt `specs/001-etap1-fundament/contracts/firewall-dropin.md`).

**Komenda** [ops]:

```bash
ansible-playbook playbooks/verify/stage1.yml --tags us4
ansible db1 -b -a "nft list chain inet filter input"
```

**Weryfikacja**: `failed=0`; w wyjściu: `web1 → db1:3306 RESULT=timeout`, lokalnie na `db1`
`RESULT=connected`, `web1 → db1:22 RESULT=timeout`, `ops → db1:22 RESULT=connected`. Łańcuch
`input` ma `policy drop` i reguły z komentarzami `common: ...`.

Testy ręczne [PS]:

| Scenariusz | Komenda | Oczekiwany wynik |
|---|---|---|
| US4.4 host → ops | `ssh -i .lab\ssh\id_ed25519 admin@192.168.56.5 hostname` | `ops` |
| US4.4 host → inny węzeł | `ssh -o ConnectTimeout=5 -i .lab\ssh\id_ed25519 admin@192.168.56.31` | `Connection timed out` |
| US4.5 trwałość po restarcie | `vagrant reload db1`, potem [ops] `ansible db1 -b -a "nft list chain inet filter input"` | `policy drop`, reguła SSH z 192.168.56.5 |
| US4.6 kanał zarządzania | `vagrant ssh db1 -c hostname`; `vagrant halt web2`; `vagrant up web2` | `db1`; zatrzymanie i start bez błędów |

**Typowe problemy**:

- *Objaw*: `ping` między węzłami nie działa. To celowe — ICMP echo jest zamknięty; łączność
  sprawdzaj `ansible all -m ping`.
- *Objaw*: test `us4` zgłasza `refused` zamiast `timeout`. *Przyczyna*: reguła `reject` zamiast
  polityki `drop` albo brak firewalla. *Sprawdzenie*: `nft list ruleset` na `db1`.

## Krok 9. Czas i aktualizacje (US5)

**Co**: UTC i chrony na 7 węzłach; automatycznie tylko poprawki bezpieczeństwa, bez restartów.

**Dlaczego**: [ADR 0007](../adr/0007-aktualizacje-bez-restartow.md); w etapie 4 Corosync i
replikacja wymagają zgodnych zegarów.

**Komenda** [ops]:

```bash
ansible-playbook playbooks/verify/stage1.yml --tags us5
ansible all -b -a "needrestart -b -k"
```

**Weryfikacja**: `failed=0`; `needrestart` → kod 0 i linia `NEEDRESTART-KSTA: 1` (restart
niewymagany) lub `2`/`3` (wymagany — węzeł nie restartuje się sam).

Przesunięcie zegara (US5.2) [PS]: `vagrant ssh web1 -c "sudo date -s '-2 min'"`, odczekaj do
5 min, [ops] `ansible web1 -a "chronyc tracking"` → `Leap status : Normal` i `Last offset`
≈ −120 s (zegar przestawiony o całe przesunięcie); w dzienniku
`ansible web1 -b -a "journalctl -u chrony --since -10min"` widać `Backward time jump detected!`, a
potem `System clock was stepped by 119.99... seconds`. Pomiar: ok. 3 min.

Uwaga: `System time` w `chronyc tracking` nie nadaje się do tego testu — po skoku zegara chrony
traci źródła (`Not synchronised`) i do czasu ponownej synchronizacji pokazuje tam ~0 s.

**Typowe problemy**:

- *Objaw*: `Leap status : Not synchronised`. *Przyczyna*: brak dostępu do NTP przez NAT.
  *Sprawdzenie*: `chronyc sources -v`. *Naprawa*: sieć hosta; w ostateczności własny serwer w
  `common_ntp_pools` (`group_vars`).
- *Objaw*: po dodaniu `validate: chronyd -p -f %s` do szablonu `chrony.conf` — `Could not open
  .../.source.conf : Permission denied`. *Przyczyna*: profil AppArmor `chronyd` pozwala czytać
  tylko `/etc/chrony/...`, a nie plik tymczasowy Ansible (`journalctl -k | grep apparmor`).
  *Naprawa*: tak jak w roli — walidacja w handlerze, przed restartem, na pliku docelowym.
- *Objaw*: `NEEDRESTART-KSTA: 3` na wszystkich węzłach zaraz po pierwszym przebiegu. Oczekiwane:
  jednorazowa pełna aktualizacja zainstalowała nowsze jądro, a węzły celowo nie restartują się
  same ([ADR 0007](../adr/0007-aktualizacje-bez-restartow.md)). Restart ręczny:
  `vagrant reload <węzeł>` [PS].

## Krok 10. Pełne odtworzenie od zera

**Co**: zniszcz i odtwórz lab 3 razy z rzędu (SC-001).

**Komenda**: [PS] `vagrant destroy -f; vagrant up`, potem [ops]
`ansible-playbook playbooks/site.yml && ansible-playbook playbooks/site.yml && ansible-playbook playbooks/verify/stage1.yml`.

**Weryfikacja**: za każdym razem przebieg 1 `failed=0 unreachable=0`, przebieg 2 `changed=0`,
weryfikacja `failed=0`. PLAY RECAP obu przebiegów trafia do opisu PR.

---

## Test CI (US6)

**Co**: lint w GitHub Actions wykrywa błędy, a ochrona gałęzi `main` blokuje merge przy
czerwonym statusie.

**Dlaczego**: konstytucja, zasada III i sekcja Git; workflow `.github/workflows/lint.yml`.

| Scenariusz | Komenda [WSL] | Oczekiwany wynik |
|---|---|---|
| US6.1 poprawny kod | `git push -u origin 001-etap1-fundament` | job `lint` zielony (zakładka Actions) |
| US6.2 celowy błąd | dodaj zadanie bez `name` w `roles/common/tasks/hosts.yml`, `git commit --no-verify -am "test: lint error"`, `git push` | job `lint` czerwony, log wskazuje plik i linię (`name[missing]`) |
| US6.2 cofnięcie | `git revert --no-edit HEAD`, `git push` | job zielony |
| US6.3 hook lokalny | ten sam błąd, `git commit -am "..."` (bez `--no-verify`) | commit odrzucony przez `ansible-lint` |
| Blokada merge | PR `001-etap1-fundament` → `main` z czerwonym jobem | przycisk merge nieaktywny: „Required status check lint has not succeeded” |

**Ochrona gałęzi `main`** (GitHub → Settings → Branches → Add classic branch protection rule),
wzorzec `main`:

| Ustawienie | Wartość | Dlaczego |
|---|---|---|
| *Require a pull request before merging* | tak, wymagane zatwierdzenia: **0** | zmiany tylko przez PR; przy jednym autorze GitHub nie pozwala zatwierdzić własnego PR, więc 1 zatwierdzenie zablokowałoby każdy merge |
| *Require status checks to pass* | check **`lint`** | czerwony lint blokuje merge (US6.2) |
| *Require branches to be up to date* | nie | jedna gałąź etapu naraz — wymóg tylko dokładałby przebiegi CI |
| *Do not allow bypassing the above settings* | tak | reguły obowiązują także właściciela repo |
| *Allow force pushes* / *Allow deletions* | nie | historia `main` jest niezmienna |

To samo z wiersza poleceń [WSL] (wymaga `gh auth login`):

```bash
gh api -X PUT repos/<użytkownik>/<repo>/branches/main/protection --input - <<'EOF'
{"required_status_checks":{"strict":false,"contexts":["lint"]},
 "enforce_admins":true,
 "required_pull_request_reviews":{"required_approving_review_count":0},
 "restrictions":null,"allow_force_pushes":false,"allow_deletions":false}
EOF
```

**Weryfikacja**: `gh pr view <nr> --json mergeStateStatus` → `BLOCKED` przy czerwonym `lint`,
`CLEAN` po poprawce. Check `lint` da się wybrać w ustawieniach dopiero po pierwszym przebiegu
workflow w repo.

---

## Typowe problemy — przegląd

| Objaw | Krok |
|---|---|
| `$'\r': command not found` (CRLF) | 1 |
| ansible.cfg ignorowany (katalog `0777`) | 2, 4 |
| VirtualBox wolny obok Hyper-V | 3 |
| brak `vboxsf` (dodatki gościa) | 3 |
| host ma inny adres niż 192.168.56.1 | 4 |
| `127.0.1.1` w `getent hosts` | 5 |
| `ssh admin@192.168.56.5` „wisi” przy pierwszym połączeniu | 4 |
| przerwany przebieg (restart, repozytorium pakietów) | 5 |
| usługi na starej konfiguracji po przerwanym przebiegu (handlery) | 5 |
| `grub-pc` / `You must correct your GRUB install devices` | 5 |
| `Unable to start service apt-daily.timer` | 5 |
| `changed` w drugim przebiegu | 6 |
| utrata SSH po zmianie konfiguracji | 7 |
| `refused` zamiast `timeout` w teście firewalla | 8 |
| `Leap status : Not synchronised` | 9 |
| `Permission denied` przy walidacji `chrony.conf` (AppArmor) | 9 |
| `NEEDRESTART-KSTA: 3` po pierwszym przebiegu | 9 |
| merge zablokowany / check `lint` niedostępny w ustawieniach | Test CI |

Szczegóły i nowe przypadki: `docs/notes.md`.
