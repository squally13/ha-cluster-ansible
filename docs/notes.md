# Notatki z problemów i weryfikacji

Dziennik prowadzony od pierwszego dnia (konstytucja, zasada VI). Z wpisów powstają sekcje
„Typowe problemy” w tutorialach etapów, postmortemy i „Czego się nauczyłem”.

**Format wpisu**:

```text
### RRRR-MM-DD — krótki tytuł
- Objaw:
- Hipotezy:
- Sprawdzenie:
- Przyczyna:
- Naprawa:
```

## Etap 1

### Organizacja pracy (T002)

| Issue | Historyjka |
|---|---|
| #1 | US1 — Odtworzenie środowiska od zera |
| #2 | US2 — Idempotentna konfiguracja bazowa |
| #3 | US3 — Bezpieczny dostęp administracyjny |
| #4 | US4 — Firewall z domyślną odmową |
| #5 | US5 — Czas, strefa czasowa i aktualizacje |
| #6 | US6 — Automatyczna kontrola jakości kodu |
| #7 | US7 — Dokumentacja etapu jako tutorial |
| #8 | Etap 1: zamknięcie etapu |

Issues mają label `etap-1` i treść skopiowaną ze `spec.md`. Tablica: GitHub Project
[„HA cluster — Etap 1: fundament”](https://github.com/users/squally13/projects/2), podpięty do
repo, pole `Status`: Todo / In Progress / Done. Issues zakładane przez `gh` (2026-11-10).

### 2026-11-09 — weryfikacja pozycji [WERYFIKACJA] z research.md (T007)

- **(a) Obraz `bento/debian-13` (R2)**: najnowsza wersja w Vagrant Cloud `202510.26.0`, dostępna
  dla providera `virtualbox` w architekturze `amd64` (także arm64, vmware_desktop, parallels).
  Przypięta w `Vagrantfile` (`box_version`). Obecność dodatków gościa VirtualBoxa — obrazy Bento
  je zawierają; do potwierdzenia przy pierwszym `vagrant up` (`mount | grep vboxsf` na `ops`).
- **(b) ansible-core i ansible-lint (R7)**: na PyPI dostępne gałęzie 2.20 (2.20.11), 2.21
  (2.21.6) i 2.22 (2.22.0) — wszystkie wydane/łatane 2026-11-02 i zgodne z Pythonem 3.13 z
  Debiana 13. Wybrano **ansible-core 2.21.6**: najnowsza łatka stabilnej gałęzi; 2.22.0 to
  wydanie `.0` sprzed tygodnia (pierwsze łatki zwykle naprawiają regresje), a 2.20 zbliża się do
  końca wsparcia. `ansible-lint 26.11.0` wymaga `ansible-core>=2.16.19,!=2.17.*` — zgodny.
  Kolekcje: `ansible.posix 2.2.2` (wymaga ansible ≥ 2.16), `community.general 14.0.0`
  (wymaga ansible ≥ 2.19) — zgodne. Inne narzędzia: `yamllint 1.38.0`, `pre-commit 4.7.0`,
  `pre-commit-hooks v6.0.0`, `actions/checkout v7.0.1`, `actions/setup-python v7.1.0`.
  Decyzja R7 zmieniona względem „docelowo 2.20” — research.md zaktualizowany.
- **(c) Wersje na hoście**: `VBoxManage --version` → `7.2.16r174877` (VirtualBox 7.x — OK).
  Vagrant początkowo niezainstalowany; po instalacji `vagrant --version` → `Vagrant 2.4.9`
  (2.4.x — OK).

### 2026-11-09 — testy akceptacyjne przed implementacją

Kontrakt testów zakłada uruchomienie `playbooks/verify/stage1.yml --tags usN` przed
implementacją każdej historyjki (oczekiwana porażka). Playbooki weryfikacyjne powstały razem z
implementacją, zanim środowisko było dostępne (brak Vagranta na hoście), więc przebiegów „przed”
nie wykonano (wykonane 2026-11-09 — wpis „testy akceptacyjne przed `site.yml`”). Do odnotowania przy pierwszym uruchomieniu: na świeżo postawionych maszynach (po
`vagrant up`, przed `site.yml`) uruchomić `verify/stage1.yml` i zapisać tu, które asercje padły
(oczekiwane: US1.4 — `127.0.1.1`/brak wpisów, US3 — `sshd -T`, US4 — brak `policy drop`,
US5 — strefa czasowa/konfiguracja aktualizacji).

### 2026-11-09 — pierwszy `vagrant up` (T028)

- `vagrant up` (box pobierany pierwszy raz): **6 min 44 s**; 7 maszyn, bootstrap bez błędów.
  `vboxsf` na `ops` działa (dodatki gościa w obrazie Bento potwierdzone).
- `ansible all -m ping` → 7× `pong`; `ansible-config dump` czyta `/vagrant/ansible.cfg`.
- Uwaga: ruch z WSL2 do 192.168.56.0/24 wychodzi przez Windows jako **192.168.56.1** — z WSL
  można więc łączyć się z `ops` tak jak z PowerShella.

### 2026-11-09 — `ssh admin@192.168.56.5` z PowerShella „wisi” po dodaniu klucza hosta

- Objaw: po `Warning: Permanently added '192.168.56.5'` brak znaku zachęty, Enter nic nie robi.
- Sprawdzenie: z WSL `ssh -i <klucz> admin@192.168.56.5` z PTY — powłoka, `.profile`
  (`ANSIBLE_CONFIG`, `cd /vagrant`) działają; w logu `Last login ... from 192.168.56.1`, czyli
  sesja z PowerShella też się zalogowała.
- Przyczyna: po stronie terminala Windows (pierwsze połączenie z pytaniem o klucz hosta).
- Naprawa: ponowne `ssh -i .lab\ssh\id_ed25519 admin@192.168.56.5` (klucz hosta już znany);
  alternatywnie `vagrant ssh ops` + `sudo -iu admin`.

### 2026-11-09 — testy akceptacyjne przed `site.yml` (T029, T036, T043, T049)

Na świeżych maszynach (po `vagrant up`, przed `site.yml`) — zgodnie z oczekiwaniem wszystkie
historyjki czerwone:

| Tag | Wynik | Co padło |
|---|---|---|
| us1 | failed 7/7 | US1.4 `getent hosts <inny węzeł>` — brak wpisów (US1.2, US1.3 zielone) |
| us3 | failed 7/7 | SC-004 `sshd -T`: `allowusers=[]` (US3.1 sudo zielone) |
| us4 | failed 7/7 | US4.5 `nft list chain inet filter input` — brak tabeli |
| us5 | failed 7/7 | US5.1 `chronyc` — brak pakietu chrony |

### 2026-11-09 — `grub-pc` przerywa jednorazową pełną aktualizację

- Objaw: `apt-get dist-upgrade` → `dpkg: error processing package grub-pc (--configure)`,
  `You must correct your GRUB install devices before proceeding`.
- Hipotezy: (1) brak miejsca w `/boot`; (2) debconf wskazuje nieistniejący dysk.
- Sprawdzenie: `debconf-show grub-pc` → `grub-pc/install_devices:` puste/nieaktualne,
  `install_devices_failed_upgrade: true`; `ls /dev/disk/by-id` → dysk `ata-VBOX_HARDDISK_<inny
  numer>`.
- Przyczyna: obraz Bento zapamiętał dysk maszyny, na której był budowany; każdy klon ma dysk o
  innym numerze seryjnym.
- Naprawa: zadanie `debconf` (`grub-pc/install_devices` = `common_grub_install_devices`,
  domyślnie `/dev/sda`) przed jednorazową aktualizacją. Ponowny przebieg dokończył konfigurację
  `grub-pc` (`dpkg --audit` pusty) — potwierdzone zachowanie „przerwany przebieg → ponowne
  uruchomienie `site.yml` dokańcza konfigurację”.

### 2026-11-09 — walidacja `chronyd -p -f %s` blokowana przez AppArmor

- Objaw: `Fatal error : Could not open /home/admin/.ansible/tmp/.../.source.conf : Permission denied`
  (także z `-u root`).
- Sprawdzenie: `journalctl -k | grep apparmor` → `apparmor="DENIED" profile="/usr/sbin/chronyd"`.
- Przyczyna: profil AppArmor `chronyd` pozwala czytać tylko własne ścieżki (`/etc/chrony/...`).
- Naprawa: walidacja przeniesiona do handlera (`chronyd -p -f /etc/chrony/chrony.conf` przed
  restartem) — błędna konfiguracja przerywa przebieg, działający `chronyd` zostaje.

### 2026-11-09 — timery `apt-daily*` nie startują (usługi zamaskowane w obrazie)

- Objaw: `Unable to start service apt-daily.timer: Job failed`; journal: `Refusing to start,
  unit apt-daily.service to trigger not loaded`.
- Przyczyna: obraz Bento maskuje `apt-daily.service` i `apt-daily-upgrade.service`
  (`/etc/systemd/system/*.service -> /dev/null`). Bez naprawy poprawki bezpieczeństwa **nigdy**
  by się nie instalowały, a pierwotny test US5 tego nie wykrywał.
- Naprawa: zadanie odmaskowania usług w `updates.yml`; test US5.3 rozszerzony o sprawdzenie, że
  usługi nie są zamaskowane, a timery są aktywne.

### 2026-11-09 — handlery utracone po błędzie w środku przebiegu

- Objaw: przebieg przerwany na timerach APT; wcześniejsze zmiany `sshd_config`, `nftables.conf`
  i `chrony.conf` zapisane, ale handlery (restart/przeładowanie) się nie wykonały. Kolejny
  przebieg nie wywoła ich ponownie (pliki już aktualne) — konfiguracja nieaktywna do restartu.
- Naprawa: `force_handlers = True` w `ansible.cfg`; maszyny odtworzone od zera.

### 2026-11-09 — odtworzenie od zera po poprawkach (próba 1/3 dla SC-001)

| Krok | Wynik |
|---|---|
| `vagrant destroy -f && vagrant up` (box w cache) | 5 min 44 s, rc=0 |
| `site.yml` przebieg 1 | 4 min 47 s; 7/7 `failed=0 unreachable=0` (`changed=23`) |
| **SC-003** (`vagrant up` + przebieg 1) | **~10,5 min** (≤ 30 min) |
| `site.yml` przebieg 2 | 7/7 `changed=0 failed=0` |
| `site.yml --check --diff` | 7/7 `changed=0`, brak różnic |
| `verify/stage1.yml` | 7/7 `failed=0`; `web1→db1:3306 timeout`, `db1 lokalnie connected`, `web1→db1:22 timeout`, `ops→db1:22 connected` |

Testy ręczne:

- US2.3 dryf na `lb1` → `lb1 changed=2` (zadanie szablonu + handler `Restart ssh`); kolejny
  przebieg 7/7 `changed=0`. Spec/quickstart mówiły `changed=1` — handler też liczy się jako
  zmiana; tutorial poprawiony.
- US3.5 `BlednaOpcja tak` w `sshd_config.j2` → `fatal` z `Bad configuration option: BlednaOpcja`
  (walidacja `sshd -t`), logowanie na węzeł działa; po cofnięciu 7/7 `changed=0`.
- US4.4 host → `ops`: `hostname` = `ops`; host → `db1:22`: `Connection timed out`.
- US4.5 `vagrant reload db1` → `policy drop` i reguła `ip saddr 192.168.56.5 tcp dport 22`.
- US4.6 `vagrant ssh db1 -c hostname` → `db1`; `vagrant halt web2` / `vagrant up web2` bez błędów.
- US5.2 `date -s '-2 min'` na `web1` → po ~5 min `Leap status: Normal`, przesunięcie 6 ms.
  Mieści się w limicie, ale na granicy — przy powtórce zmierzyć dokładnie (zmierzone
  2026-11-11: ok. 3 min, patrz próby 2/3 i 3/3).
- US5.4 `needrestart -b -k` → `NEEDRESTART-KSTA: 3` na 7/7: jednorazowa aktualizacja
  zainstalowała nowe jądro (`linux-image-6.12.116+deb13`), węzły **nie** zrestartowały się same.
- R9: w logu aktualizacji `ssh.socket is a disabled or a static unit not running` — Debian 13
  używa `ssh.service`, handler `Restart ssh` jest właściwy (potwierdzone dryfem US2.3).

### 2026-11-10 — test CI i ochrona `main` (T057)

| Scenariusz | Wynik |
|---|---|
| US6.1 push `6b95e8d` | job `lint` zielony (1 min 1 s) |
| US6.3 `git commit` z zadaniem bez `name` | odrzucony przez hook: `name[missing]` `roles/common/tasks/hosts.yml:14` |
| US6.2 `git commit --no-verify` + push (`68b8731`) | job `lint` czerwony; log: `##[error]All tasks should be named.` `roles/common/tasks/hosts.yml:14` |
| Blokada merge | draft PR #9 → `main`: `mergeStateStatus: BLOCKED` |
| Cofnięcie (`git revert`) + push | `push` i `pull_request` zielone; PR #9 `CLEAN` |

- Ochrona `main` (klasyczna reguła): wymagany PR z **0** zatwierdzeń (jedyny autor nie może
  zatwierdzić własnego PR), wymagany check `lint`, bez obejścia dla administratora, bez force
  push i usuwania. Szczegóły w tutorialu, sekcja „Test CI”.
- Draft PR #9 zostaje — w T069 dostanie pełny opis.

### 2026-11-11 — odtworzenie od zera, próby 2/3 i 3/3 (T065, SC-001–SC-003)

Bez zmian w kodzie ról od próby 1/3 (między próbami tylko dokumentacja i para commitów testu CI
z T057, która się znosi). Sekwencja: `vagrant destroy -f`, `vagrant up`, na `ops` `site.yml` ×2,
`site.yml --check --diff`, `verify/stage1.yml`.

| Krok | Próba 1/3 (11-09) | Próba 2/3 | Próba 3/3 |
|---|---|---|---|
| `vagrant destroy -f` | — | 28 s | 23 s |
| `vagrant up` (box w cache) | 5 min 44 s | 5 min 37 s | 6 min 6 s |
| `site.yml` przebieg 1 | 4 min 47 s | 5 min 2 s | 4 min 49 s |
| **SC-003** (`up` + przebieg 1) | ~10 min 31 s | **10 min 39 s** | **10 min 55 s** |
| przebieg 1 | 7/7 `failed=0 unreachable=0`, `changed=23` | to samo | to samo |
| przebieg 2 | 7/7 `changed=0` | 7/7 `changed=0` | 7/7 `changed=0` |
| `--check --diff` | 7/7 `changed=0`, brak różnic | to samo | to samo |
| `verify/stage1.yml` | 7/7 `failed=0` | 7/7 `failed=0` | 7/7 `failed=0` |

SC-001 (3× z rzędu bez błędów) i SC-002 (`changed=0` w drugim przebiegu) spełnione; SC-003 z
zapasem (limit 30 min). Czasy wpisane do ADR 0002.

Po próbie 3/3:

- **R8**: `nft -c -f /etc/nftables.conf` → rc=0 na 7/7; `/etc/nftables.d/` zawiera
  `00-common.nft` — `include` z wzorcem zawsze ma dopasowanie.
- **US5.2 dokładnie**: `date -s '-2 min'` na `web1` (10:11:04 UTC). Dziennik chrony:
  `Backward time jump detected!` → `Can't synchronise: no selectable sources` → po ~3 min
  `Selected source ...`, `System clock wrong by 119.998131 seconds`, `System clock was stepped by
  119.998131 seconds` (`makestep 1 -1`). Odpytywanie co ~21 s: `Leap status : Normal` po 191 s,
  `Last offset : -119.998 s`. Wynik: ~3 min (≤ 5 min).
  - Pułapka: przez cały czas desynchronizacji `chronyc tracking` pokazywał
    `System time : 0.000000001 seconds` — ta wartość nie mierzy błędu zegara po skoku.
    Poprzedni pomiar („6 ms po ~5 min”) opierał się na niej. Tutorial poprawiony: kryterium to
    `Leap status : Normal` + `Last offset` ≈ −120 s + wpis `stepped` w dzienniku.
  - Uboczne: `Received KoD RATE` z serwerów `debian.pool.ntp.org` — 7 węzłów za jednym NAT-em
    odpytuje te same serwery; na synchronizację nie wpływa. Gdyby się nasiliło: `ops` jako
    lokalny serwer czasu dla pozostałych węzłów (kandydat na etap 4, Corosync).

### Pozycje do sprawdzenia przy pierwszym uruchomieniu

- ~~R9 socket activation~~ — sprawdzone: `ssh.service`.
- ~~R8~~ — sprawdzone 2026-11-11 (`nft -c` rc=0 na 7/7). Pierwotnie: `include "/etc/nftables.d/*.nft"` przy pustym katalogu — rola od razu tworzy plik
  `/etc/nftables.d/00-common.nft` (sam komentarz), więc wzorzec zawsze ma dopasowanie; sprawdzić
  `nft -c -f /etc/nftables.conf` mimo to.
- ~~R11~~ — sprawdzone: cache apt nie daje `changed` w drugim przebiegu; `needrestart -b -k`
  działa (kod 0, `NEEDRESTART-KSTA:`).
