---

description: "Task list for Etap 1 — Fundament"
---

# Tasks: Etap 1 — Fundament

**Input**: Design documents from `/specs/001-etap1-fundament/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: Spec wymaga testowalnych scenariuszy akceptacyjnych, a plan (R13) — playbooka
weryfikacyjnego. Każda historyjka ma więc zadania testowe w `playbooks/verify/stage1/usN.yml`
(kontrakt: [contracts/verification.md](contracts/verification.md)), pisane **przed** implementacją
i uruchamiane po niej. Infrastruktura nie ma klasycznego cyklu „czerwone → zielone” — test
przed implementacją MUSI zakończyć się porażką albo błędem braku zasobu, co jest zapisywane w
`docs/notes.md`.

**Organization**: zadania pogrupowane według historyjek ze spec. Ścieżki względem korzenia repo
(po przeniesieniu na NTFS — T001).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: można wykonywać równolegle (inne pliki, brak zależności od niedokończonych zadań)
- **[Story]**: historyjka ze spec (US1…US7)

## Konwencje obowiązujące w każdym zadaniu (konstytucja)

- Zmienne z prefiksem `common_` w `roles/common/defaults/main.yml`; nadpisywanie tylko w
  `inventories/lab/group_vars|host_vars`.
- Każdy szablon zaczyna się nagłówkiem `# Zarządzane przez Ansible — nie edytuj ręcznie`
  (`{{ ansible_managed }}` lub stały tekst).
- Restart/przeładowanie wyłącznie przez handlery z [contracts/common-role.md](contracts/common-role.md).
- Zadania `command`/`shell` MUSZĄ mieć `changed_when` (lub `creates`).
- Każde zadanie MUSI mieć `name` po polsku i tag z kontraktu.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: repozytorium we właściwym miejscu, z ustawieniami Git i szkieletem dokumentacji.

- [X] T001 Przenieś projekt z WSL (`~/klaster-ha`: `.specify/`, `.claude/`, `specs/`, `Plan_projektu_klaster_HA.md`) do katalogu na NTFS, np. `C:\Users\<user>\projects\ha-homelab`; zainicjuj Git (`git init -b main`), zrób commit startowy na `main` (konstytucja, `specs/`, plan projektu: `docs: add constitution and stage 1 spec`), utwórz publiczne repo na GitHubie, ustaw `origin`, wypchnij `main`, a następnie utwórz gałąź etapu `git switch -c 001-etap1-fundament` — cała dalsza praca etapu trafia na tę gałąź (R1; konstytucja, sekcja Git)
- [ ] T002 Załóż w GitHubie Project (tablica Kanban: Todo / In progress / Done) i Issues dla etapu 1 — po jednym na historyjkę US1–US7 oraz jeden „Etap 1: zamknięcie etapu” — z kryteriami akceptacji skopiowanymi ze `specs/001-etap1-fundament/spec.md`; numery Issues zapisz w `docs/notes.md` (konstytucja: definicja ukończenia pkt 7, sekcja Git)
- [X] T003 Utwórz `.gitattributes` z `* text=auto eol=lf` oraz `*.ps1 text eol=crlf` w korzeniu repo (R1)
- [X] T004 [P] Utwórz `.gitignore` z wpisami `.lab/`, `.vagrant/`, `.vault_pass`, `*.retry`, `__pycache__/` (R5, R15)
- [X] T005 [P] Utwórz `docs/notes.md` z nagłówkiem i sekcją „Etap 1” (format wpisu: data, objaw, hipotezy, sprawdzenie, przyczyna, naprawa) zgodnie z zasadą VI
- [X] T006 [P] Utwórz szablon ADR `docs/adr/0000-szablon.md` z sekcjami: Status (Proponowany/Przyjęty/Zastąpiony przez NNNN), Kontekst, Decyzja, Rozważane alternatywy, Konsekwencje (w tym „co na produkcji”) — zasada V
- [X] T007 Zweryfikuj pozycje **[WERYFIKACJA]** z research.md i zapisz wyniki w `docs/notes.md`: (a) najnowsza wersja `bento/debian-13` dla providera virtualbox i obecność dodatków gościa (R2), (b) aktualna wspierana gałąź `ansible-core` zgodna z Pythonem 3.13 i zgodna z nią wersja `ansible-lint` (R7), (c) wersje VirtualBox 7.x i Vagrant 2.4.x na hoście (`VBoxManage --version`, `vagrant --version`); jeśli wynik zmienia decyzję — zaktualizuj research.md
- [X] T008 [P] Utwórz `requirements-ops.txt` z `ansible-core==<wersja z T007>` (dokładne przypięcie, R7)
- [X] T009 [P] Utwórz `requirements.yml` z kolekcjami `ansible.posix` i `community.general` w dokładnych wersjach (`version: "X.Y.Z"`), zgodnych z wersją ansible-core z T007 (R7)
- [X] T010 [P] Utwórz `requirements-dev.txt` z przypiętymi `yamllint`, `ansible-lint` (wersja z T007) i `pre-commit` (R12)
- [X] T011 [P] Utwórz `.yamllint` (rozszerza `default`; `line-length: max 120`; `truthy` dopuszcza `true/false`; ignoruje `.lab/`, `.vagrant/`, `specs/`, `.specify/`)
- [X] T012 [P] Utwórz `.ansible-lint` (`profile: production`, `exclude_paths: [.lab/, .vagrant/, specs/, .specify/, .github/]`; ewentualne `skip_list` tylko z komentarzem uzasadniającym)
- [X] T013 [P] Utwórz `.pre-commit-config.yaml` z hookami `yamllint` i `ansible-lint` w wersjach z `requirements-dev.txt` oraz `check-yaml`, `end-of-file-fixer`, `trailing-whitespace`, `mixed-line-ending --fix=lf` z `pre-commit-hooks`
- [X] T014 [P] Utwórz `.github/workflows/lint.yml`: wyzwalacze `push` i `pull_request`; `ubuntu-latest`, Python 3.13; `pip install -r requirements-dev.txt`; `ansible-galaxy collection install -r requirements.yml`; `yamllint .`; `ansible-lint`; akcje przypięte do wersji (np. `actions/checkout@v4`, `actions/setup-python@v5`)
- [X] T015 Zainstaluj na hoście narzędzia z `requirements-dev.txt` i hooki (`pre-commit install`); uruchom `pre-commit run --all-files` → wszystko `Passed`; od tej chwili każdy commit przechodzi przez lint (konstytucja, zasada III)
- [X] T016 Utwórz `ansible.cfg`: `inventory = inventories/lab/hosts.yml`, `roles_path = roles`, `remote_user = admin`, `private_key_file = ~/.ssh/id_ed25519`, `host_key_checking = False` (z komentarzem: lab odtwarzany od zera, klucze hostów zmieniają się przy każdym `vagrant destroy`), `interpreter_python = /usr/bin/python3`, `stdout_callback = default` z `result_format = yaml`, `[ssh_connection] pipelining = True`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: maszyny powstają, `ops` ma Ansible i klucz, `ansible all -m ping` działa, a rola
`common` ma szkielet zgodny z kontraktem.

**⚠️ CRITICAL**: żadna historyjka nie może się zacząć przed końcem tej fazy.

- [X] T017 Utwórz `inventories/lab/hosts.yml` — **jedyne źródło listy maszyn** (R3) — z grupami `ops`, `lb`, `web`, `db` i hostami: `ops` 192.168.56.5 / 1024, `lb1` 192.168.56.11 / 512, `lb2` 192.168.56.12 / 512, `web1` 192.168.56.21 / 1024, `web2` 192.168.56.22 / 1024, `db1` 192.168.56.31 / 1536, `db2` 192.168.56.32 / 1536 (zmienne `ansible_host`, `vagrant_memory`); reguły z data-model.md: nazwa `^[a-z][a-z0-9]*$`, `ansible_host` unikalny, „w 192.168.56.0/24; różny od VIP (.10) i hosta (.1)”, grupa „dokładnie jedna z: `ops`, `lb`, `web`, `db`”
- [X] T018 [P] Utwórz `inventories/lab/host_vars/ops.yml` z `ansible_connection: local` (R5/R8: `ops` nie łączy się sam ze sobą po SSH)
- [X] T019 [P] Utwórz `inventories/lab/group_vars/all/main.yml` z `common_vip_address: 192.168.56.10` i `common_ssh_host_address: 192.168.56.1` (z komentarzem, jak sprawdzić adres hosta w sieci host-only: `ipconfig` → „VirtualBox Host-Only Network”)
- [X] T020 [P] Napisz `vagrant/bootstrap-node.sh` (idempotentny, `set -euo pipefail`): argument = klucz publiczny labu; tworzy konto `admin` (`/bin/bash`, katalog domowy), `~admin/.ssh/authorized_keys` (`0600`, właściciel `admin`), `/etc/sudoers.d/admin` (`0440`, `root:root`) o treści **identycznej** z szablonem `roles/common/templates/sudoers_admin.j2` z T038 (nagłówek „Zarządzane przez Ansible” + `admin ALL=(ALL) NOPASSWD:ALL`), walidowany `visudo -cf`; ponowne uruchomienie nie zmienia stanu (R5)
- [X] T021 [P] Napisz `vagrant/bootstrap-ops.sh` (idempotentny): instaluje `python3-venv`, `git`; tworzy venv `/opt/ansible` i instaluje `-r /vagrant/requirements-ops.txt`; linkuje `ansible*` do `/usr/local/bin`; jako `admin` instaluje kolekcje `ansible-galaxy collection install -r /vagrant/requirements.yml`; kopiuje `/vagrant/.lab/ssh/id_ed25519` do `~admin/.ssh/id_ed25519` z `install -m 0600 -o admin -g admin`; dopisuje do `~admin/.profile` `export ANSIBLE_CONFIG=/vagrant/ansible.cfg` i `cd /vagrant` tylko jeśli wpisu brak (R5, R6)
- [X] T022 Napisz `Vagrantfile` (depends on T017, T020, T021): wczytuje `inventories/lab/hosts.yml` (YAML) i w pętli tworzy maszyny z `vagrant_memory` i `ansible_host` na sieci `private_network`; box `bento/debian-13` z `box_version` z T007; **nie** ustawia `config.vm.hostname` (R4); `vb.name = "ha-homelab-<nazwa>"`, `vb.linked_clone = true`; jeśli brak `.lab/ssh/id_ed25519` — generuje parę `ssh-keygen -t ed25519 -N "" -C ha-homelab-lab -f .lab/ssh/id_ed25519`; synced folder `/vagrant` wyłączony (`disabled: true`) na wszystkich poza `ops`, na `ops` z `mount_options: ["dmode=755", "fmode=644"]` (R6); provisioner shell `vagrant/bootstrap-node.sh` z kluczem publicznym jako argumentem na każdym węźle, a na `ops` dodatkowo `vagrant/bootstrap-ops.sh`; maszyna `ops` definiowana jako ostatnia
- [X] T023 Utwórz szkielet roli `roles/common/`: `meta/main.yml` (autor, `min_ansible_version`, platforma Debian trixie), `defaults/main.yml` ze **wszystkimi** zmiennymi z [contracts/common-role.md](contracts/common-role.md) i ich wartościami domyślnymi, `handlers/main.yml` z handlerami `Restart ssh` (`listen: restart ssh`), `Restart chrony` (`listen: restart chrony`), `Reload nftables` (`listen: reload firewall`; najpierw `nft -c -f /etc/nftables.conf`, potem `nft -f /etc/nftables.conf`, oba z `changed_when` właściwym dla handlera)
- [X] T024 Utwórz `roles/common/tasks/main.yml` z `import_tasks` w kolejności z FR-018 / kontraktu: `packages.yml` (tag `packages`), `users.yml` (`users`), `hosts.yml` (`hosts`), `time.yml` (`time`), `firewall.yml` (`firewall`), `ssh.yml` (`ssh`), `updates.yml` (`updates`); utwórz te pliki jako puste listy zadań (`---` + komentarz „wypełniane w USn”) w `roles/common/tasks/`
- [X] T025 Wypełnij `roles/common/tasks/packages.yml`: instalacja `common_packages` (`apt`, `update_cache: true`, `cache_valid_time: 3600`); jednorazowa pełna aktualizacja (`upgrade: dist`) tylko gdy `common_initial_upgrade` i brak znacznika `/var/lib/ha-homelab/initial-upgrade.done` (`stat`), potem utworzenie znacznika (katalog `0755`, plik `0644`) — R11, data-model „Znacznik pierwszej aktualizacji”
- [X] T026 Utwórz `playbooks/common.yml` (`hosts: all`, `become: true`, rola `common` z tagiem `common`) oraz `playbooks/site.yml` z `import_playbook: common.yml`
- [X] T027 Utwórz `playbooks/verify/stage1.yml` importujący `stage1/us1.yml`, `stage1/us3.yml`, `stage1/us4.yml`, `stage1/us5.yml` (każdy import z tagiem `usN`), oraz `playbooks/verify/files/tcp_probe.py`: argumenty `host port timeout`, wypisuje dokładnie `RESULT=<connected|refused|timeout> HOST=<ip> PORT=<port>`, kod wyjścia 0 zawsze (wynik oceniany w playbooku) — kontrakt verification.md
- [ ] T028 Uruchom `vagrant up` (PowerShell na hoście), zaloguj się na `ops` (`vagrant ssh ops`, `sudo -iu admin`) i wykonaj `ansible all -m ping` → 7× `pong`; potwierdź `ansible-config dump --only-changed` pokazuje ustawienia z `/vagrant/ansible.cfg` (brak ostrzeżenia o katalogu z prawem zapisu dla wszystkich); problemy zapisz w `docs/notes.md`

**Checkpoint**: środowisko powstaje, Ansible z `ops` dociera do 7 hostów — historyjki mogą ruszyć.

---

## Phase 3: User Story 1 — Odtworzenie środowiska od zera (Priority: P1) 🎯 MVP

**Goal**: jedna udokumentowana sekwencja „zniszcz → utwórz → skonfiguruj” daje 7 poprawnie
zaadresowanych węzłów, które widzą się po nazwach.

**Independent Test**: `vagrant destroy -f && vagrant up`, potem na `ops`
`ansible-playbook playbooks/site.yml` i `ansible-playbook playbooks/verify/stage1.yml --tags us1`.

### Tests for User Story 1

- [ ] T029 [US1] Napisz `playbooks/verify/stage1/us1.yml` (hosts: all): US1.2 `ping`; US1.3 asercja, że `ansible_host` ∈ 192.168.56.0/24 i jest na liście `ansible_all_ipv4_addresses`; US1.4 `getent hosts` dla każdego innego hosta z inventory → adres = jego `ansible_host`, oraz `getent hosts $(hostname)` ≠ `127.0.1.1` i = własny `ansible_host`; uruchom przed implementacją — US1.4 MUSI się nie udać (zapisz w `docs/notes.md`)

### Implementation for User Story 1

- [X] T030 [P] [US1] Utwórz szablon `roles/common/templates/hosts.j2`: `127.0.0.1 localhost`, wpisy IPv6 localhost, każdy host z `groups['all']` jako `<ansible_host> <nazwa>`, `common_vip_address vip`; **bez** linii `127.0.1.1` (R4, FR-010)
- [X] T031 [US1] Wypełnij `roles/common/tasks/hosts.yml`: `ansible.builtin.hostname` = `inventory_hostname`; szablon `hosts.j2` → `/etc/hosts` (`root`, `0644`)
- [ ] T032 [US1] Uruchom na `ops` `ansible-playbook playbooks/site.yml`, potem `ansible-playbook playbooks/verify/stage1.yml --tags us1` → wszystkie asercje zielone; PLAY RECAP: `failed=0 unreachable=0` dla 7 hostów

**Checkpoint**: MVP — środowisko odtwarzalne, węzły adresowane i rozwiązywane poprawnie.

---

## Phase 4: User Story 2 — Idempotentna konfiguracja bazowa (Priority: P1)

**Goal**: drugi przebieg `site.yml` daje `changed=0`, `--check --diff` nie pokazuje różnic, a
ręczny dryf jest cofany.

**Independent Test**: dwa kolejne przebiegi `site.yml`; drugi `changed=0` na 7 hostach.

**Uwaga**: tę fazę powtarza się po każdej kolejnej historyjce (US3–US5), bo każda dokłada zadania.

### Tests for User Story 2

- [X] T033 [US2] Dodaj do `docs/stages/01-fundament.md` (utwórz plik z nagłówkiem, jeśli nie istnieje) sekcję „Test idempotencji” z poleceniami i oczekiwanym wynikiem: przebieg 2 `changed=0`; `--check --diff` bez różnic; test dryfu (US2.3) z quickstart.md — to jest procedura testowa US2

### Implementation for User Story 2

- [ ] T034 [US2] Uruchom `ansible-playbook playbooks/site.yml` drugi raz; dla każdego zadania raportującego `changed` usuń przyczynę w odpowiednim pliku `roles/common/tasks/*.yml` (typowo: odświeżenie cache apt — R11 [WERYFIKACJA], `command` bez `changed_when`); powtarzaj do `changed=0`; przyczyny i poprawki zapisz w `docs/notes.md`
- [ ] T035 [US2] Wykonaj `ansible-playbook playbooks/site.yml --check --diff` → brak różnic (US2.2); wykonaj test dryfu z quickstart.md (US2.3) → `changed=1` na `lb1`, kolejny przebieg `changed=0`

**Checkpoint**: idempotencja potwierdzona dla zadań z US1.

---

## Phase 5: User Story 3 — Bezpieczny dostęp administracyjny (Priority: P1)

**Goal**: `admin` loguje się wyłącznie kluczem labu z dozwolonego źródła; hasła, root i
`vagrant` z sieci labu są odrzucane; zły szablon SSH nie psuje działającej konfiguracji.

**Independent Test**: `ansible-playbook playbooks/verify/stage1.yml --tags us3` + test US3.5 z
quickstart.md.

### Tests for User Story 3

- [ ] T036 [US3] Napisz `playbooks/verify/stage1/us3.yml`: US3.1 `become` + `id -u` = `0`; z `ops` (delegacja na `ops`) dla każdego innego hosta: US3.2 `ssh -o BatchMode=yes -o PreferredAuthentications=password -o PubkeyAuthentication=no admin@<ip>` → kod ≠ 0 i komunikat bez metody `password`; US3.3 `ssh -o BatchMode=yes -i ~/.ssh/id_ed25519 root@<ip>` → odrzucone; US3.4 `ssh -o BatchMode=yes vagrant@<ip>` → odrzucone, oraz `passwd -S vagrant` na węźle → status `L`; **dodatkowo na każdym z 7 węzłów, łącznie z `ops` (SC-004)**, sprawdzenie efektywnej konfiguracji `sshd -T` (`become`): `passwordauthentication no`, `kbdinteractiveauthentication no`, `permitrootlogin no`, a `allowusers` zawiera dokładnie oczekiwane wpisy (dla `ops`: `admin@<common_ssh_host_address>` i `vagrant@10.0.2.2`; dla pozostałych: `admin@192.168.56.5` i `vagrant@10.0.2.2`) — same próby logowania nie wystarczą, bo `root` i `vagrant` nie mają klucza labu i byłyby odrzucone także bez konfiguracji; wszystkie `ssh` z `-o ConnectTimeout=5 -o StrictHostKeyChecking=no`, `changed_when: false`, `failed_when` na podstawie oczekiwanego wyniku; uruchom przed implementacją (oczekiwana porażka US3.2 i asercji `sshd -T`)

### Implementation for User Story 3

- [X] T037 [P] [US3] Utwórz `roles/common/templates/sshd_config.j2` — cały plik, bez `Include`: `PasswordAuthentication no`, `KbdInteractiveAuthentication no`, `PermitRootLogin no`, `PubkeyAuthentication yes`, `UsePAM yes`, `X11Forwarding no`, `Subsystem sftp /usr/lib/openssh/sftp-server`, `AllowUsers`: dla `ops` — `{{ common_admin_user }}@{{ common_ssh_host_address }} vagrant@{{ common_mgmt_ssh_source }}`, dla pozostałych — `{{ common_admin_user }}@{{ common_control_node_address }} vagrant@{{ common_mgmt_ssh_source }}` (R9)
- [X] T038 [US3] Wypełnij `roles/common/tasks/users.yml`: konto `common_admin_user` (`shell: /bin/bash`), `ansible.posix.authorized_key` z `lookup('file', common_admin_pubkey_path)` z `exclusive: true`, szablon `roles/common/templates/sudoers_admin.j2` → `/etc/sudoers.d/admin` (`root:root`, `0440`, `validate: visudo -cf %s`; treść identyczna z plikiem tworzonym przez bootstrap T020 — bez zmian w pierwszym i drugim przebiegu), `ansible.builtin.user: name=vagrant password_lock=true` (FR-008a)
- [ ] T039 [US3] Wypełnij `roles/common/tasks/ssh.yml`: szablon `sshd_config.j2` → `/etc/ssh/sshd_config` (`root`, `0600`), `validate: /usr/sbin/sshd -t -f %s`, `notify: restart ssh`; usługa `ssh` `enabled`/`started`; sprawdź na węźle `systemctl status ssh.socket ssh.service` (R9 [WERYFIKACJA]) i dostosuj handler w `roles/common/handlers/main.yml`, jeśli Debian 13 używa socket activation
- [ ] T040 [US3] Uruchom `site.yml` ×2 (drugi `changed=0`), potem `verify/stage1.yml --tags us3` → zielone; wykonaj ręcznie US3.5 (błąd w `sshd_config.j2` → zadanie `failed` przez `sshd -t`, logowanie nadal działa; cofnięcie → `changed=0`) i zapisz wynik w `docs/notes.md`
- [X] T041 [P] [US3] Napisz `docs/adr/0005-bootstrap-klucze-labu.md` (Clarify Q3, R5: para kluczy labu, bootstrap `admin` przed Ansible, dlaczego nie `vagrant`, dlaczego nie `ansible_local`)
- [X] T042 [P] [US3] Napisz `docs/adr/0006-konto-vagrant.md` (Clarify Q4: konto zostaje, hasło zablokowane, `AllowUsers vagrant@10.0.2.2`; na produkcji brak takiego konta)

**Checkpoint**: hardening SSH działa i jest idempotentny.

---

## Phase 6: User Story 4 — Firewall z domyślną odmową (Priority: P1)

**Goal**: polityka `drop`, w etapie 1 otwarte tylko SSH z `ops`, SSH z hosta do `ops` i kanał
zarządzania Vagranta; reguły trwałe i rozszerzalne fragmentami.

**Independent Test**: `ansible-playbook playbooks/verify/stage1.yml --tags us4` + ręczne US4.4,
US4.5, US4.6 z quickstart.md.

### Tests for User Story 4

- [ ] T043 [US4] Napisz `playbooks/verify/stage1/us4.yml`: na `db1` w `block`/`always` uruchom tymczasowy nasłuch TCP 3306 (`python3 -c` z `socket`, w tle przez `async`/`poll: 0`, zakończony w `always`); z `web1` (`delegate_to`) `tcp_probe.py 192.168.56.31 3306 3` → wymagane `RESULT=timeout`; na `db1` `tcp_probe.py 127.0.0.1 3306 3` → `RESULT=connected` (US4.1, US4.2); z `web1` `tcp_probe.py 192.168.56.31 22 3` → `RESULT=timeout`, z `ops` → `RESULT=connected` (US4.3); na każdym węźle `nft list chain inet filter input` zawiera `policy drop` i `systemctl is-enabled nftables` = `enabled` (US4.5); skrypt kopiowany z `playbooks/verify/files/tcp_probe.py` do `/tmp` i usuwany na końcu; wszystkie zadania `command`/`shell` (nasłuch, sondy, sprzątanie) z `changed_when: false` (konstytucja, zasada II; reguła `no-changed-when` w ansible-lint); uruchom przed implementacją (oczekiwana porażka)

### Implementation for User Story 4

- [X] T044 [P] [US4] Utwórz `roles/common/templates/nftables.conf.j2` zgodnie z [contracts/firewall-dropin.md](contracts/firewall-dropin.md) i data-model.md „Reguły etapu 1”: `flush ruleset`; `table inet filter` z łańcuchem `input` (`policy drop`): `iif lo accept`, `ct state established,related accept`, `ct state invalid drop`, `iifname "{{ ansible_default_ipv4.interface }}" tcp dport 22 accept comment "common: kanał zarządzania Vagranta"`, dla `ops` `ip saddr {{ common_ssh_host_address }} tcp dport 22 accept`, dla pozostałych `ip saddr {{ common_control_node_address }} tcp dport 22 accept` (każda z `comment "common: ..."`); łańcuch `forward` `policy drop`, `output` `policy accept`; po tabeli `include "/etc/nftables.d/*.nft"`
- [X] T045 [US4] Wypełnij `roles/common/tasks/firewall.yml`: katalog `/etc/nftables.d` (`root`, `0755`); sprawdź zachowanie `include` z pustym katalogiem (`nft -c -f`) — jeśli błąd, dodaj `/etc/nftables.d/00-placeholder.nft` z samym komentarzem (ryzyko z plan.md); szablon `nftables.conf.j2` → `/etc/nftables.conf` (`root`, `0755`) z `validate: nft -c -f %s`, `notify: reload firewall`; usługa `nftables` `enabled`/`started`
- [ ] T046 [US4] Uruchom `site.yml` ×2 (bez utraty połączenia w trakcie — FR-018; drugi `changed=0`), potem `verify/stage1.yml --tags us4` → zielone; wykonaj ręcznie US4.4, US4.5 (`vagrant reload db1`), US4.6 (`vagrant ssh`, `vagrant halt web2` / `vagrant up web2`) z quickstart.md i zapisz wyniki w `docs/notes.md`
- [X] T047 [P] [US4] Napisz `docs/adr/0004-firewall-nftables-porty-per-etap.md` (sprzeczność planu: krok 4 vs kryterium 3306; decyzja: w etapie 1 tylko SSH; mechanizm fragmentów `/etc/nftables.d`; ICMP echo zamknięty)
- [X] T048 [P] [US4] Napisz `docs/adr/0003-ops-wezel-sterujacy.md` (Q3 + Clarify Q5: Ansible z `ops`, `ops` lokalnie bez SSH, źródła SSH: `ops` → węzły, 192.168.56.1 → `ops`, obrona w głąb nft + `AllowUsers`)

**Checkpoint**: firewall działa, testy odróżniają blokadę od braku usługi.

---

## Phase 7: User Story 5 — Czas, strefa czasowa i aktualizacje bezpieczeństwa (Priority: P2)

**Goal**: UTC i chrony na 7 węzłach (różnica < 1 s), automatyczne poprawki tylko security, bez
restartów, z sygnałem „wymagany restart”; narzędzia bazowe obecne.

**Independent Test**: `ansible-playbook playbooks/verify/stage1.yml --tags us5` + ręczne US5.2,
US5.4.

### Tests for User Story 5

- [ ] T049 [US5] Napisz `playbooks/verify/stage1/us5.yml`: US5.1 `chronyc tracking` → `Leap status : Normal` i |`System time`| < 0,5 s; US5.3 `timedatectl show -p Timezone --value` = `UTC`, `/etc/apt/apt.conf.d/50unattended-upgrades` zawiera tylko wzorce `-security` i `Unattended-Upgrade::Automatic-Reboot "false";`; US5.4 konfiguracja `needrestart` zawiera `$nrconf{restart} = 'l';`, a `needrestart -b -k` kończy się kodem 0 i wypisuje linię `NEEDRESTART-KSTA:`; US5.5 `command -v vim htop curl rsync tcpdump` → wszystkie obecne; `changed_when: false`; uruchom przed implementacją (oczekiwana porażka strefy/konfiguracji)

### Implementation for User Story 5

- [X] T050 [P] [US5] Utwórz `roles/common/templates/chrony.conf.j2`: `pool` dla każdego z `common_ntp_pools` z `iburst maxpoll 6`, `makestep 1 -1`, `driftfile /var/lib/chrony/chrony.drift`, `rtcsync`, `leapsectz right/UTC` (R10)
- [X] T051 [US5] Wypełnij `roles/common/tasks/time.yml`: `community.general.timezone: name="{{ common_timezone }}"`; szablon `chrony.conf.j2` → `/etc/chrony/chrony.conf` (`root`, `0644`), `notify: restart chrony`; usługa `chrony` `enabled`/`started`
- [X] T052 [P] [US5] Utwórz szablony `roles/common/templates/50unattended-upgrades.j2` (`Unattended-Upgrade::Origins-Pattern` tylko `origin=Debian,codename=${distro_codename}-security,label=Debian-Security` i `...codename=${distro_codename}-security`, `Unattended-Upgrade::Automatic-Reboot "false";`), `20auto-upgrades.j2` (`APT::Periodic::Update-Package-Lists "1"; APT::Periodic::Unattended-Upgrade "1";`) i `needrestart.conf.j2` (`$nrconf{restart} = 'l';`) (R11)
- [ ] T053 [US5] Wypełnij `roles/common/tasks/updates.yml`: szablony z T052 → `/etc/apt/apt.conf.d/50unattended-upgrades`, `/etc/apt/apt.conf.d/20auto-upgrades`, `/etc/needrestart/conf.d/50-ha-homelab.conf` (`root`, `0644`); timery `apt-daily.timer` i `apt-daily-upgrade.timer` `enabled`; sprawdź `needrestart -b -k` na Debianie 13 (R11 [WERYFIKACJA]) i zapisz wynik w `docs/notes.md`
- [ ] T054 [US5] Uruchom `site.yml` ×2 (drugi `changed=0`), potem `verify/stage1.yml --tags us5` → zielone; wykonaj ręcznie US5.2 (przesunięcie zegara na `web1`, powrót ≤ 5 min) i opcjonalną symulację US5.4 z quickstart.md (instalacja dodatkowego pakietu jądra → `NEEDRESTART-KSTA` 2 lub 3, węzeł nie restartuje się sam; po teście przywrócenie przez odtworzenie węzła); wyniki w `docs/notes.md`
- [X] T055 [P] [US5] Napisz `docs/adr/0007-aktualizacje-bez-restartow.md` (Clarify Q2, R11: tylko security, brak automatycznych restartów, jednorazowy pełny upgrade ze znacznikiem, sygnał przez needrestart; na produkcji: okna serwisowe rozłożone w parach HA)

**Checkpoint**: wszystkie wymagania konfiguracji bazowej (FR-006…FR-012) spełnione.

---

## Phase 8: User Story 6 — Automatyczna kontrola jakości kodu (Priority: P2)

**Goal**: lint lokalnie (pre-commit) i w CI; błędny kod nie trafia do `main`.

**Independent Test**: gałąź z celowym błędem → czerwony job; poprawka → zielony.

**Uwaga**: konfiguracja lintu i CI powstaje już w Phase 1; ta faza jedynie sprawdza działanie CI i włącza ochronę `main`.

### Tests for User Story 6

- [X] T056 [US6] Opisz w `docs/stages/01-fundament.md` sekcję „Test CI” (scenariusze US6.1–US6.3: komendy, oczekiwany wynik, jak sprawdzić blokadę merge)

### Implementation for User Story 6

Pliki konfiguracji lintu i CI powstają w Phase 1 (T011–T014, T015), żeby lint obejmował wszystkie commity od początku.

- [ ] T057 [US6] Wypchnij gałąź `001-etap1-fundament`, zweryfikuj zielony job; wypchnij commit z celowym błędem (US6.2) → czerwony job ze wskazaniem pliku i linii, potem go cofnij; włącz w GitHubie ochronę gałęzi `main` wymagającą statusu `lint` i opisz ustawienie w `docs/stages/01-fundament.md`

**Checkpoint**: lint chroni `main`.

---

## Phase 9: User Story 7 — Dokumentacja etapu jako tutorial (Priority: P3)

**Goal**: osoba trzecia odtwarza etap 1 z dokumentacji bez pytań do autora; każda decyzja ma ADR.

**Independent Test**: przejście `docs/stages/01-fundament.md` na czystym hoście (US7.2).

### Implementation for User Story 7

- [X] T058 [P] [US7] Napisz `docs/adr/0001-debian-13.md` (Q2, R2: Debian 13 vs 12 vs Rocky 9; ryzyko pakietów MySQL 8.4/HAProxy 2.8 do sprawdzenia przed etapami 2 i 4; przypięta wersja boxa z T007)
- [X] T059 [P] [US7] Napisz `docs/adr/0002-vagrant-virtualbox-windows.md` (Q1, R1, R14: Vagrant + VirtualBox na Windowsie, repo na NTFS, LF, współistnienie z Hyper-V i zmierzony czas z SC-003; wersje VirtualBox/Vagrant z T007)
- [X] T060 [P] [US7] Napisz `docs/adr/0008-folder-wspoldzielony-ops.md` (Clarify Q1, R6: tylko na `ops`, `dmode=755,fmode=644`, `ANSIBLE_CONFIG`, ochrona klucza w `.lab/`; w „Konsekwencjach” jawnie: na `ops` plik `/vagrant/.lab/ssh/id_ed25519` jest czytelny dla każdego lokalnego użytkownika (`fmode=644`) — akceptowalne w labie, bo jedyni użytkownicy `ops` (`admin`, `vagrant`) i tak mają sudo i dostęp do tego klucza; na produkcji klucz nie leżałby w katalogu współdzielonym)
- [X] T061 [P] [US7] Napisz `docs/adr/0009-jedno-zrodlo-listy-maszyn.md` (R3, R4: `hosts.yml` czytany przez Vagrantfile; brak `config.vm.hostname` i dlaczego)
- [X] T062 [US7] Uzupełnij `docs/stages/01-fundament.md` jako tutorial (zasada VI): dla każdego kroku z quickstart.md — **Co**, **Dlaczego** (z linkiem do ADR), **Komenda** (z hostem: PowerShell na Windowsie / `ops` jako `admin`), **Weryfikacja** z oczekiwanym wynikiem, **Typowe problemy** (min.: VirtualBox obok Hyper-V, CRLF, `ansible.cfg` ignorowany w katalogu `0777`, inny adres hosta niż 192.168.56.1, `127.0.1.1`, `changed` w drugim przebiegu, brak dodatków gościa w obrazie, przerwany przebieg — restart węzła lub niedostępne repozytorium pakietów: objaw, sprawdzenie, ponowne uruchomienie `site.yml` dokańcza konfigurację); wymagania sprzętowe i wersje narzędzi
- [X] T063 [P] [US7] Napisz `docs/architecture.md` (szkic etapu 1): tabela maszyn z data-model.md, sieć 192.168.56.0/24, adres hosta, kanał NAT, reguły firewalla etapu 1 i zapowiedź reguł kolejnych etapów (kontrakt fragmentów)
- [X] T064 [US7] Utwórz `README.md`: tytuł i jedno zdanie o projekcie, status „Etap 1 — Fundament”, szybki start (4–5 poleceń: `git clone` → `vagrant up` → `vagrant ssh ops` → `sudo -iu admin` → `ansible-playbook playbooks/site.yml`) z wymaganiami sprzętowymi, linki do tutorialu, ADR i `docs/architecture.md`, informacja o `.lab/` (klucz labu, nie commitować); sekcja „Sekrety” (konstytucja, zasada IV): sekrety trafiają do zaszyfrowanego `inventories/lab/group_vars/all/vault.yml` od etapu 2, a hasło do vaulta trzyma się w pliku `.vault_pass` (ignorowanym przez Git) — jak go utworzyć (`openssl rand -base64 32 > .vault_pass`, uprawnienia tylko dla właściciela) i jak go użyć (`--vault-password-file .vault_pass` albo `vault_password_file` w `ansible.cfg`)

**Checkpoint**: dokumentacja kompletna; etap gotowy do walidacji końcowej.

---

## Phase 10: Polish & Cross-Cutting Concerns (zamknięcie etapu)

**Purpose**: definicja ukończenia etapu z konstytucji.

- [ ] T065 Wykonaj pełne odtworzenie od zera 3 razy z rzędu (`vagrant destroy -f && vagrant up`, na `ops`: `site.yml` ×2, `verify/stage1.yml`) — za każdym razem przebieg 1 `failed=0 unreachable=0`, przebieg 2 `changed=0` na 7/7 hostach, weryfikacja zielona (SC-001, SC-002); zmierz czas `vagrant up` + przebieg 1 (SC-003 ≤ 30 min) i wpisz do ADR 0002
- [X] T066 Przejrzyj `roles/common/` pod kątem zasady III: każdy plik konfiguracyjny z szablonu z nagłówkiem, brak `lineinfile`, brak bezwarunkowych restartów, `validate:` dla `sshd_config` i `nftables.conf`, każde zadanie z `name` i tagiem; `ansible-lint` bez wyjątków nieuzasadnionych
- [X] T067 Sprawdź, że w historii Git nie ma `.lab/`, klucza prywatnego ani `.vault_pass` (`git log --all --stat | grep -E "\.lab/|id_ed25519|vault_pass"` → pusto) — zasada IV
- [ ] T068 Uzupełnij `docs/notes.md` o wszystkie problemy z etapu; przenieś powtarzalne do sekcji „Typowe problemy” w `docs/stages/01-fundament.md`
- [ ] T069 Utwórz pull request `001-etap1-fundament` → `main` z opisem: zakres, PLAY RECAP obu przebiegów z T065, wynik `verify/stage1.yml`, czas z SC-003, linki do ADR 0001–0009 i Issues (`Closes #...`); lint zielony
- [ ] T070 Poproś osobę trzecią o przejście tutorialu na jej komputerze (SC-008, US7.2); każde miejsce, w którym utknęła, popraw w `docs/stages/01-fundament.md` (może nastąpić po merge — wtedy jako Issue)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: T001 pierwszy (wszystko inne powstaje już w repo na NTFS); T007 przed T008–T010 i T022.
- **Foundational (Phase 2)**: zależy od Setup; T017 → T022; T020, T021 → T022; T023 → T024 → T025; T028 na końcu fazy. **Blokuje US1–US5 i US7.**
- **US1 (Phase 3)**: po Foundational. MVP.
- **US2 (Phase 4)**: po US1 (potrzebuje działającego `site.yml`); powtarzana po US3, US4, US5.
- **US3, US4, US5 (Phases 5–7)**: po Foundational; edytują różne pliki zadań i szablonów, więc są niezależne. Zalecana kolejność US3 → US4, bo reguły firewalla zakładają `AllowUsers` i źródła SSH z US3 (obrona w głąb), ale każda daje się przetestować osobno.
- **US6 (Phase 8)**: zależy tylko od Setup (T001, T010, T011–T014, T015) — może iść równolegle ze wszystkim.
- **US7 (Phase 9)**: ADR-y mogą powstawać od razu po decyzji; T062 i T064 po US1–US5 (tutorial opisuje gotowe kroki).
- **Polish (Phase 10)**: po wszystkich historyjkach.

### User Story Dependencies

- **US1 (P1)**: tylko Foundational.
- **US2 (P1)**: US1 (do testu potrzebny jest playbook z zadaniami).
- **US3 (P1)**: Foundational; integruje się z US4 przez wspólne źródła SSH (`common_control_node_address`, `common_ssh_host_address`) zdefiniowane w T023/T019.
- **US4 (P1)**: Foundational; zalecana po US3.
- **US5 (P2)**: Foundational.
- **US6 (P2)**: Setup.
- **US7 (P3)**: treść z US1–US5.

### Within Each User Story

- Test (`playbooks/verify/stage1/usN.yml`) przed implementacją i jego porażka zapisana w `docs/notes.md`.
- Szablony przed zadaniami, które ich używają.
- Po implementacji: `site.yml` ×2 (`changed=0`) → test historyjki → ADR.

### Parallel Opportunities

- Setup: T004, T005, T006 razem; po T007: T008, T009, T010 razem.
- Foundational: T018, T019, T020, T021 razem (po T017).
- US3: T037 równolegle z T036; T041, T042 równolegle z czymkolwiek.
- US4: T044 równolegle z T043; T047, T048 równolegle.
- US5: T050 i T052 razem; T055 równolegle.
- Setup: T011–T014 razem (po T010); US6 (T056, T057) równolegle z US1–US5.
- US7: T058–T061 i T063 razem.

---

## Parallel Example: User Story 4

```bash
# Równolegle: test i szablon (różne pliki)
Task: "Napisz playbooks/verify/stage1/us4.yml (T043)"
Task: "Utwórz roles/common/templates/nftables.conf.j2 (T044)"

# Równolegle po wdrożeniu: ADR-y
Task: "docs/adr/0004-firewall-nftables-porty-per-etap.md (T047)"
Task: "docs/adr/0003-ops-wezel-sterujacy.md (T048)"
```

## Parallel Example: Setup + US6

```bash
Task: "Utwórz .gitignore (T004)"
Task: "Utwórz docs/notes.md (T005)"
Task: "Utwórz docs/adr/0000-szablon.md (T006)"
# po T010:
Task: "Utwórz .yamllint (T011)"
Task: "Utwórz .ansible-lint (T012)"
Task: "Utwórz .pre-commit-config.yaml (T013)"
Task: "Utwórz .github/workflows/lint.yml (T014)"
```

---

## Implementation Strategy

### MVP First (User Story 1)

1. Phase 1: Setup (w tym przeniesienie repo i weryfikacje z T007).
2. Phase 2: Foundational — `vagrant up` + `ansible all -m ping`.
3. Phase 3: US1 — hostname i `/etc/hosts`, test `--tags us1`.
4. **STOP and VALIDATE**: `vagrant destroy -f && vagrant up` + `site.yml` → zielone.

### Incremental Delivery

1. Setup + Foundational → środowisko i łączność.
2. US1 → MVP (odtwarzalność) → US2 (idempotencja).
3. US3 → US2 ponownie → US4 → US2 ponownie → US5 → US2 ponownie.
4. Lint i CI działają od Phase 1; US6 tylko weryfikuje CI i ochronę `main`.
5. US7 → Phase 10 (3× odtworzenie, PR).

### Commity

Małe commity w formacie `<obszar>: <co zmieniono>` (np. `common: add nftables base ruleset`,
`vagrant: generate lab ssh key on first up`, `docs: add ADR 0004 firewall per stage`), co
najmniej jeden na zadanie lub logiczną grupę.

---

## Notes

- [P] = różne pliki, brak zależności od niedokończonych zadań.
- [USn] = mapowanie na historyjkę ze spec.
- `roles/common/tasks/main.yml`, `defaults/main.yml` i `handlers/main.yml` powstają w całości w
  Phase 2, żeby historyjki nie edytowały tych samych plików.
- Każdy problem trwający > 2 h → Issue z listą sprawdzonych hipotez (konstytucja, sekcja Git).
