# Research: Etap 1 — Fundament

**Data**: 2026-11-08 | **Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

Każda decyzja ma format: Decyzja / Uzasadnienie / Rozważane alternatywy. Pozycje oznaczone
**[WERYFIKACJA]** to fakty zależne od stanu zewnętrznych projektów w dniu implementacji —
pierwsze zadanie etapu potwierdza je i ewentualnie koryguje decyzję (z wpisem w ADR).

---

## R1. Lokalizacja repozytorium na hoście (konsekwencja Q1)

- **Decyzja**: Repozytorium robocze leży na systemie plików Windows (NTFS), np.
  `C:\Users\<user>\projects\ha-homelab`. Vagrant i VirtualBox działają na Windowsie z tego
  katalogu. WSL (jeśli używany) widzi repo przez `/mnt/c/...`. Plik `.gitattributes` wymusza
  końce linii LF (`* text=auto eol=lf`).
- **Uzasadnienie**: folder współdzielony VirtualBoxa (FR-005a) wymaga ścieżki dostępnej dla
  procesu VirtualBoxa na Windowsie; ścieżki `\\wsl$\...` nie są wspierane jako synced folder.
  Pliki edytowane na Windowsie z CRLF psują skrypty powłoki i część szablonów na Linuksie.
- **Alternatywy**: repo w WSL + rsync na Windows przed `vagrant up` (dodatkowy krok, dwie kopie);
  Vagrant w WSL z `VAGRANT_WSL_ENABLE_WINDOWS_ACCESS` (odrzucone w Q1).
- **Skutek dla bieżącego katalogu**: obecny katalog `~/klaster-ha` w WSL (z `.specify/` i
  `specs/`) należy przenieść na NTFS przed implementacją — zadanie wstępne w `tasks.md`.

## R2. Obraz bazowy Debian 13 dla VirtualBoxa

- **Decyzja**: `bento/debian-13` z przypiętą `box_version`. **[WERYFIKACJA]** dostępność wersji
  amd64/virtualbox i obecność dodatków gościa VirtualBoxa (wymagane dla `vboxsf`).
- **Uzasadnienie**: obrazy Bento zawierają dodatki gościa (folder współdzielony bez dodatkowych
  pluginów), są szeroko używane i wersjonowane.
- **Alternatywy**: `debian/trixie64` (oficjalne, ale bez dodatków gościa → tylko rsync, brak
  zgodności z FR-005a); plugin `vagrant-vbguest` (dodatkowa zależność, kruchy przy nowych
  jądrach).

## R3. Jedno źródło listy maszyn (FR-001, FR-004)

- **Decyzja**: lista maszyn (nazwa, IP, RAM, grupa) jest zdefiniowana tylko w
  `inventories/lab/hosts.yml`; `Vagrantfile` czyta ten plik (YAML) i tworzy maszyny w pętli.
  Pamięć maszyny to zmienna hosta `vagrant_memory`.
- **Uzasadnienie**: brak duplikacji między Vagrantfile a inventory; dodanie węzła (runbook
  `add-web-node`) zmienia jeden plik.
- **Alternatywy**: lista w Vagrantfile + generowanie inventory (inventory staje się artefaktem
  pochodnym, trudniejsze do czytania); duplikacja w obu plikach (ryzyko rozjazdu).

## R4. Nazwa hosta i `/etc/hosts` (FR-010)

- **Decyzja**: Vagrantfile NIE ustawia `config.vm.hostname`; nazwę hosta ustawia Ansible
  (`ansible.builtin.hostname`), a `/etc/hosts` jest w całości generowany z szablonu (wszystkie
  hosty z inventory + `vip` 192.168.56.10, bez wpisu `127.0.1.1 <hostname>`).
- **Uzasadnienie**: Vagrant przy `vagrant up/reload` dopisuje własną nazwę na `127.0.1.1`, co
  (a) psuje Corosync w etapie 4, (b) powoduje dryf i `changed` przy kolejnym przebiegu.
- **Alternatywy**: zostawić `config.vm.hostname` i nadpisywać plik (walka dwóch narzędzi o ten
  sam plik).

## R5. Bootstrap: konto `admin`, para kluczy labu, Ansible na `ops` (FR-005, FR-007a)

- **Decyzja**:
  1. `Vagrantfile` przy każdym uruchomieniu sprawdza `.lab/ssh/id_ed25519`; jeśli brak —
     generuje parę `ssh-keygen -t ed25519 -N ""` (OpenSSH jest wbudowany w Windows 10/11).
     Katalog `.lab/` jest w `.gitignore`.
  2. Minimalny provisioner powłoki (plik `vagrant/bootstrap-node.sh`, idempotentny) na każdym
     węźle: tworzy konto `admin` z kluczem publicznym labu i sudo bez hasła. Klucz publiczny
     jest przekazywany jako argument provisionera (nie przez folder współdzielony).
  3. Na `ops` dodatkowo `vagrant/bootstrap-ops.sh`: instaluje Ansible w wirtualnym środowisku
     Pythona `/opt/ansible` z przypiętych wersji (`requirements-ops.txt`), instaluje kolekcje z
     `requirements.yml`, kopiuje klucz prywatny do `~admin/.ssh/id_ed25519` z `0600`.
  4. Dalsze zarządzanie kontem `admin` przejmuje rola `common` (ten sam stan → brak zmian).
- **Uzasadnienie**: problem „jajka i kury” — Ansible na `ops` musi się zalogować do węzłów,
  zanim cokolwiek skonfiguruje, a konto `vagrant` nie może być używane z sieci labu (FR-008a).
  Bootstrap jest kodem w repo (zasada I) i robi tylko minimum.
- **Alternatywy**: pierwsze połączenie jako `vagrant` (sprzeczne z FR-008a); provisioner
  `ansible_local` Vagranta (ukrywa uruchamianie Ansible w `vagrant up`, utrudnia drugi przebieg
  i tagi; Ansible ma być uruchamiany jawnie z `ops`).

## R6. Folder współdzielony i `ansible.cfg` (FR-005a)

- **Decyzja**: folder `.` montowany jako `/vagrant` **tylko na `ops`** (na pozostałych węzłach
  `disabled: true`), z `mount_options: ["dmode=755", "fmode=644"]`. Playbooki uruchamiane z
  `/vagrant` jako użytkownik `admin`; dodatkowo w profilu `admin` na `ops` ustawione
  `ANSIBLE_CONFIG=/vagrant/ansible.cfg` jako zabezpieczenie.
- **Uzasadnienie**: Ansible ignoruje `ansible.cfg` w katalogu z prawem zapisu dla wszystkich
  (domyślne `0777` na `vboxsf`). Wyłączenie folderu na innych węzłach chroni klucz prywatny w
  `.lab/` przed dostępem z każdej maszyny.
- **Alternatywy**: tylko zmienna `ANSIBLE_CONFIG` (działa, ale katalog `0777` pozostaje);
  rsync (odrzucony w pytaniu 1 sesji clarify).
- **Uwaga**: na `vboxsf` brak bitu wykonywania — skrypty uruchamiane jawnie przez `bash`.

## R7. Ansible i kolekcje (wersje)

- **Decyzja**: `ansible-core` w najnowszej wspieranej (nie-EOL) gałęzi zgodnej z Pythonem 3.13 z
  Debiana 13, przypięty dokładnie (`==X.Y.Z`) w `requirements-ops.txt`. **Po weryfikacji
  (2026-11-09, `docs/notes.md`)**: `ansible-core==2.21.6` — najnowsza łatka stabilnej gałęzi;
  2.22.0 odrzucone jako świeże wydanie `.0`. Kolekcje: `ansible.posix 2.2.2`,
  `community.general 14.0.0`; `ansible-lint 26.11.0`.
  Kolekcje z dokładnymi wersjami w `requirements.yml`: `ansible.posix`, `community.general`
  (strefa czasowa), a od kolejnych etapów `community.mysql`, `community.docker`.
  **[WERYFIKACJA]** gałąź i zgodność `ansible-lint` z tą gałęzią.
- **Uzasadnienie**: plan wymaga ≥ 2.17; konstytucja wymaga przypięcia wersji.
- **Alternatywy**: pakiet `ansible` z Debiana 13 (wersja zależna od dystrybucji, nie przypięta
  w repo); `pipx` (mniej przejrzyste dla Recenzenta niż jawne venv).

## R8. Firewall: nftables z katalogiem fragmentów (FR-011)

- **Decyzja**: `nftables` (domyślny na Debianie 13). Rola `common` szablonuje
  `/etc/nftables.conf`: tabela `inet filter`, łańcuch `input` z polityką `drop`, reguły bazowe
  (loopback, `ct state established,related`, `ct state invalid drop`, SSH wg FR-011, SSH na
  interfejsie NAT dla kanału zarządzania), poprzedzone `flush ruleset`, a po definicji tabeli
  `include "/etc/nftables.d/*.nft"` (fragmenty to polecenia `add rule ...`).
  **[WERYFIKACJA]** zachowanie `include` z wzorcem przy pustym katalogu. Kolejne role
  dokładają własne pliki `/etc/nftables.d/<rola>.nft` (kontrakt:
  [contracts/firewall-dropin.md](contracts/firewall-dropin.md)). Walidacja `nft -c -f`,
  przeładowanie przez handler (atomowe załadowanie całego zestawu reguł). `forward` i `output`:
  odpowiednio `drop` i `accept`.
- **Uzasadnienie**: atomowe ładowanie całego zestawu wyklucza stan pośredni, w którym polityka
  `drop` obowiązuje bez reguły SSH (FR-018). Katalog fragmentów pozwala otwierać porty bez
  edycji roli bazowej.
- **Alternatywy**: `firewalld` (nie jest domyślny na Debianie, strefy komplikują reguły per
  źródło); `ufw` (warstwa nad iptables/nft, mniej przejrzysta); lista reguł w zmiennej scalanej z
  `group_vars` (Ansible nie scala list między rolami — kruche).
- **ICMP**: echo-request z sieci labu nie jest otwierany w etapie 1 (zgodnie z „wyłącznie” z
  FR-011); komunikaty ICMP błędów przechodzą jako `related`. Test łączności to moduł `ping`
  Ansible (SSH), nie ICMP.
- **Interfejs NAT**: identyfikowany jako interfejs trasy domyślnej (`ansible_default_ipv4.interface`).

## R9. SSH (FR-008, FR-008a, US3)

- **Decyzja**: cały `/etc/ssh/sshd_config` z szablonu (bez `Include sshd_config.d`, żeby żaden
  plik z obrazu nie nadpisał ustawień), `validate: /usr/sbin/sshd -t -f %s`, handler
  `Restart ssh`. Ustawienia: `PasswordAuthentication no`, `KbdInteractiveAuthentication no`,
  `PermitRootLogin no`, `PubkeyAuthentication yes`, `AllowUsers` z wzorcami `user@źródło`:
  - węzły ≠ `ops`: `admin@192.168.56.5`, `vagrant@10.0.2.2`;
  - `ops`: `admin@<adres hosta>` (domyślnie 192.168.56.1), `vagrant@10.0.2.2`.
  Hasło konta `vagrant` blokowane (`password_lock`). **[WERYFIKACJA]** czy w Debianie 13 SSH
  działa jako `ssh.service` (nie socket activation) oraz że ruch `vagrant ssh` przychodzi z
  10.0.2.2.
- **Uzasadnienie**: obrona w głąb — firewall i sshd niezależnie ograniczają źródła.
- **Alternatywy**: bloki `Match Address` (bardziej rozwlekłe przy tym samym efekcie).

## R10. Czas (FR-009, US5)

- **Decyzja**: `chrony` z pulą `debian.pool.ntp.org` przez NAT, `makestep 1 -1` (korekta
  skokowa przy każdym odchyleniu > 1 s — wybudzenie laptopa), `maxpoll 6`; strefa `UTC` przez
  `community.general.timezone`.
- **Uzasadnienie**: scenariusz US5.2 (powrót synchronizacji ≤ 5 min) wymaga krótkiego interwału
  odpytywania i korekty skokowej; w labie stabilność zegara jest ważniejsza niż płynność.
- **Alternatywy**: `systemd-timesyncd` (słabsza diagnostyka, brak `chronyc tracking` z planu);
  `ops` jako lokalny serwer NTP (dodatkowa zależność w etapie 1 — możliwe rozszerzenie).

## R11. Aktualizacje (FR-012)

- **Decyzja**:
  - `unattended-upgrades` z `Origins-Pattern` ograniczonym do `${distro_codename}-security`
    (oraz `Debian-Security`), `Automatic-Reboot "false"`.
  - Sygnał „wymagany restart”: `needrestart` w trybie tylko-listy (`$nrconf{restart} = 'l'`);
    sprawdzenie jednym poleceniem `needrestart -b -k` (`NEEDRESTART-KSTA` ≠ 1 → restart
    wymagany). **[WERYFIKACJA]** zachowanie w Debianie 13.
  - Jednorazowa pełna aktualizacja: zadanie aktualizacji wykonywane tylko, gdy nie istnieje
    znacznik `/var/lib/ha-homelab/initial-upgrade.done`; po sukcesie znacznik jest tworzony.
  - Odświeżanie cache pakietów z `cache_valid_time`; **[WERYFIKACJA]** że samo odświeżenie cache
    nie raportuje `changed` (jeśli raportuje — `changed_when` oparty na instalacji pakietów).
- **Uzasadnienie**: `changed=0` w drugim przebiegu i brak niekontrolowanych restartów pary HA.
- **Alternatywy**: pełne `apt upgrade` w każdym przebiegu (łamie zasadę II); brak
  automatycznych poprawek (gorsze bezpieczeństwo).

## R12. Lint i CI (FR-015, US6)

- **Decyzja**: `yamllint` + `ansible-lint` z przypiętymi wersjami w `requirements-dev.txt`;
  `.pre-commit-config.yaml` z tymi hookami (uruchamiany na hoście — Python na Windowsie lub WSL na
  `/mnt/c`); `.github/workflows/lint.yml` na `push` i `pull_request`; ochrona gałęzi `main`
  wymagająca zielonego statusu (konfiguracja w GitHubie opisana w dokumentacji).
- **Uzasadnienie**: wymóg konstytucji (zasada III, sekcja Git).
- **Alternatywy**: lint tylko w CI (błędy wykrywane później); `ansible-lint` z profilem
  `production` od razu — przyjęty profil `production`, a odstępstwa jawnie w `.ansible-lint`.

## R13. Weryfikacja akceptacyjna (US1–US5, SC-001…SC-006)

- **Decyzja**: playbook `playbooks/verify/stage1.yml` uruchamiany z `ops`, z tagami per
  historyjka (`us1`…`us5`), implementujący scenariusze akceptacyjne (kontrakt:
  [contracts/verification.md](contracts/verification.md)). Testy firewalla uruchamiają
  tymczasowy nasłuch (Python `socket`) i rozróżniają `timeout` od `refused`; po teście nasłuch
  jest sprzątany. Testy z perspektywy hosta (US4.4, US4.6, `vagrant ssh`) są opisane jako kroki
  ręczne w quickstart.
- **Uzasadnienie**: powtarzalne kryteria ukończenia (konstytucja: definicja ukończenia etapu),
  materiał dla Recenzenta.
- **Alternatywy**: Molecule/testinfra (cięższe; Molecule jest rozszerzeniem z planu);
  same ręczne kroki (niepowtarzalne).
- **Uwaga**: playbook weryfikacyjny nie jest częścią `site.yml` i nie wpływa na `changed=0`.

## R14. VirtualBox obok Hyper-V (ryzyko z Edge Cases)

- **Decyzja**: najpierw próba z włączonym Hyper-V (VirtualBox 7.x działa wtedy przez Windows
  Hypervisor Platform). Jeśli SC-003 (≤ 30 min) nie jest spełnione albo maszyny się zawieszają —
  udokumentowane obejście: `bcdedit /set hypervisorlaunchtype off` + restart (wyłącza też WSL2 i
  Docker Desktop na czas pracy z labem). Wynik pomiaru trafia do ADR 0002 i `docs/notes.md`.
- **Alternatywy**: Hyper-V jako provider Vagranta (sprzeczne z Q1; słabsze sieci prywatne).

## R15. Sekrety w etapie 1

- **Decyzja**: etap 1 nie tworzy `vault.yml` (brak sekretów); `.gitignore` od razu zawiera plik
  hasła do vaulta (`.vault_pass`) i `.lab/`. `vault.yml` powstaje w etapie 2 wraz z pierwszym
  sekretem.
- **Uzasadnienie**: pusty zaszyfrowany plik wymagałby hasła vaulta do każdego przebiegu bez
  żadnej korzyści; zasada IV dotyczy sekretów, a tych jeszcze nie ma.
- **Alternatywy**: pusty `vault.yml` od początku (dodatkowy krok dla Recenzenta bez wartości).
