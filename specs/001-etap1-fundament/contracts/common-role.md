# Kontrakt: interfejs roli `common`

Rola `common` jest stosowana do **wszystkich** hostów jako pierwsza w `site.yml`. Kolejne role
mogą polegać na stanie opisanym w sekcji „Gwarancje”.

## Zmienne wejściowe (`roles/common/defaults/main.yml`)

| Zmienna | Domyślnie | Opis |
|---|---|---|
| `common_packages` | `[vim, htop, curl, chrony, rsync, tcpdump, needrestart, unattended-upgrades, nftables]` | pakiety bazowe |
| `common_timezone` | `UTC` | strefa czasowa |
| `common_ntp_pools` | `[debian.pool.ntp.org]` | źródła czasu |
| `common_admin_user` | `admin` | konto administracyjne |
| `common_admin_pubkey_path` | `"{{ playbook_dir }}/../.lab/ssh/id_ed25519.pub"` | klucz publiczny labu (czytany na `ops`) |
| `common_control_node_address` | `"{{ hostvars[groups['ops'][0]].ansible_host }}"` | źródło SSH dla węzłów ≠ ops |
| `common_ssh_host_address` | `192.168.56.1` | źródło SSH do `ops` z hosta (nadpisywalne) |
| `common_mgmt_ssh_source` | `10.0.2.2` | źródło kanału zarządzania Vagranta |
| `common_vip_address` | `192.168.56.10` | wpis `vip` w `/etc/hosts` |
| `common_initial_upgrade` | `true` | jednorazowa pełna aktualizacja przy pierwszej konfiguracji |

Nadpisywanie wyłącznie w `inventories/lab/group_vars/` i `host_vars/`.

## Tagi

| Tag | Zakres |
|---|---|
| `common` | cała rola |
| `packages` | pakiety + jednorazowa aktualizacja |
| `users` | konto `admin`, blokada hasła `vagrant` |
| `ssh` | `sshd_config` |
| `time` | strefa czasowa, chrony |
| `hosts` | hostname, `/etc/hosts` |
| `firewall` | nftables |
| `updates` | unattended-upgrades, needrestart |

## Handlery

| Handler | `listen` | Akcja |
|---|---|---|
| `Restart ssh` | `restart ssh` | restart `ssh.service` |
| `Restart chrony` | `restart chrony` | restart `chrony` |
| `Reload nftables` | `reload firewall` | `nft -c -f` + `nft -f /etc/nftables.conf` |

## Gwarancje po zastosowaniu roli

- Konto `admin` z kluczem labu i sudo bez hasła; logowanie hasłem i roota wyłączone.
- Nazwa hosta = nazwa z inventory; `/etc/hosts` z wszystkimi węzłami i `vip`, bez `127.0.1.1`.
- Zegar zsynchronizowany (chrony), strefa UTC.
- nftables z polityką `drop` i katalogiem fragmentów ([firewall-dropin.md](firewall-dropin.md)).
- Automatyczne poprawki bezpieczeństwa bez automatycznego restartu.
- Wszystkie pliki konfiguracyjne z szablonów z nagłówkiem „Zarządzane przez Ansible”.

## Kolejność zadań (FR-018)

`packages` → `users` → `hosts` → `time` → `firewall` → `ssh` → `updates`.
Firewall jest ładowany atomowo z regułą SSH dla źródła, z którego łączy się Ansible; restart SSH
następuje w handlerze na końcu przebiegu i nie przerywa nawiązanych połączeń.
