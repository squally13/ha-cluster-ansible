# ha-homelab — klaster HA z Ansible

Odtwarzalny lab wysokiej dostępności (HAProxy + Pacemaker, aplikacja w kontenerach, MySQL z
replikacją) na 7 maszynach Debian 13, budowany od zera jednym `vagrant up` i jednym
`ansible-playbook`.

**Status**: Etap 1 — Fundament (maszyny, konfiguracja bazowa, SSH, firewall, czas, aktualizacje,
lint i CI).

## Szybki start

Wymagania: Windows 10/11, ≥ 16 GB RAM (lab zużywa ~7 GB), ≥ 25 GB wolnego miejsca,
VirtualBox 7.x, Vagrant 2.4.x, wbudowany klient OpenSSH. Repo musi leżeć na dysku Windows
(NTFS), nie w WSL.

```powershell
# PowerShell na hoście
git clone https://github.com/<konto>/ha-homelab.git; cd ha-homelab
vagrant up                                       # 7 maszyn, klucz labu w .lab\ssh\
ssh -i .lab\ssh\id_ed25519 admin@192.168.56.5    # albo: vagrant ssh ops; sudo -iu admin
```

```bash
# na ops, jako admin (katalog /vagrant)
ansible-playbook playbooks/site.yml
ansible-playbook playbooks/verify/stage1.yml     # testy akceptacyjne etapu 1
```

Pełny tutorial z weryfikacją i typowymi problemami: [docs/stages/01-fundament.md](docs/stages/01-fundament.md).
Architektura: [docs/architecture.md](docs/architecture.md).

## Klucz labu (`.lab/`)

Przy pierwszym `vagrant up` powstaje para kluczy `.lab/ssh/id_ed25519` — jedyny sposób logowania
na konto `admin`. Katalog `.lab/` jest w `.gitignore`: **nigdy go nie commituj**. Usunięcie
`.lab/` wymaga odtworzenia labu od zera (`vagrant destroy -f; vagrant up`).

## Sekrety

Od etapu 2 wszystkie hasła i tokeny trafiają do zaszyfrowanego pliku
`inventories/lab/group_vars/all/vault.yml` (Ansible Vault). Hasło do vaulta trzymasz w pliku
`.vault_pass` w katalogu repo — jest w `.gitignore`.

```bash
openssl rand -base64 32 > .vault_pass
chmod 600 .vault_pass
ansible-playbook playbooks/site.yml --vault-password-file .vault_pass
# albo na stałe w ansible.cfg: vault_password_file = .vault_pass
```

Zmienne jawne odwołują się do sekretów pośrednio (`mysql_root_password: "{{ vault_mysql_root_password }}"`).

## Decyzje projektowe

| ADR | Decyzja |
|---|---|
| [0001](docs/adr/0001-debian-13.md) | Debian 13 (trixie) na wszystkich węzłach |
| [0002](docs/adr/0002-vagrant-virtualbox-windows.md) | Vagrant + VirtualBox na Windowsie, repo na NTFS |
| [0003](docs/adr/0003-ops-wezel-sterujacy.md) | `ops` jako węzeł sterujący; źródła SSH |
| [0004](docs/adr/0004-firewall-nftables-porty-per-etap.md) | nftables, w etapie 1 tylko SSH, porty per etap |
| [0005](docs/adr/0005-bootstrap-klucze-labu.md) | Bootstrap: para kluczy labu i konto `admin` |
| [0006](docs/adr/0006-konto-vagrant.md) | Konto `vagrant` z zablokowanym hasłem, SSH tylko z NAT |
| [0007](docs/adr/0007-aktualizacje-bez-restartow.md) | Tylko poprawki security, bez automatycznych restartów |
| [0008](docs/adr/0008-folder-wspoldzielony-ops.md) | Folder współdzielony tylko na `ops` (755/644) |
| [0009](docs/adr/0009-jedno-zrodlo-listy-maszyn.md) | Jedno źródło listy maszyn: `hosts.yml` |

## Jakość kodu

`yamllint` + `ansible-lint` (profil `production`) lokalnie przez `pre-commit` (uruchamiany z
WSL) i w GitHub Actions na każdym pushu — czerwony lint blokuje merge do `main`.
