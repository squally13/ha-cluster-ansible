# Architektura — szkic (etap 1)

Stan po etapie 1: 7 maszyn Debian 13 z konfiguracją bazową. Usługi (MySQL, aplikacja, HAProxy,
Pacemaker) dochodzą w kolejnych etapach.

## Maszyny

Źródło prawdy: `inventories/lab/hosts.yml` ([ADR 0009](adr/0009-jedno-zrodlo-listy-maszyn.md)).

| Węzeł | IP (host-only) | RAM | Grupa | Rola docelowa |
|---|---|---|---|---|
| ops | 192.168.56.5 | 1024 MB | ops | węzeł sterujący (Ansible), później monitoring |
| lb1 | 192.168.56.11 | 512 MB | lb | HAProxy + VIP (etap 4) |
| lb2 | 192.168.56.12 | 512 MB | lb | HAProxy + VIP (etap 4) |
| web1 | 192.168.56.21 | 1024 MB | web | aplikacja w kontenerze (etap 3) |
| web2 | 192.168.56.22 | 1024 MB | web | aplikacja w kontenerze (etap 3) |
| db1 | 192.168.56.31 | 1536 MB | db | MySQL primary (etap 2) |
| db2 | 192.168.56.32 | 1536 MB | db | MySQL replika (etap 2) |
| `vip` | 192.168.56.10 | — | — | adres wirtualny (wpis w `/etc/hosts`; zasób Pacemakera w etapie 4) |

## Sieci

```text
                 Host Windows (VirtualBox, Vagrant)
                 192.168.56.1 (VirtualBox Host-Only Network)
                        │  SSH tylko do ops (admin)
   ┌────────────────────┼──────────────── 192.168.56.0/24 (host-only) ─────────────┐
   │                    │                                                          │
  ops .5 ── SSH (admin) ──► lb1 .11  lb2 .12  web1 .21  web2 .22  db1 .31  db2 .32
   │
   └── każda VM ma też interfejs NAT (10.0.2.15, brama 10.0.2.2):
       wyjście do Internetu (apt, NTP) + kanał `vagrant ssh` (przekierowany port → 22)
```

- **host-only 192.168.56.0/24** — ruch między węzłami i z hosta; adresy stałe z inventory.
- **NAT** (interfejs trasy domyślnej) — dostęp do Internetu i kanał zarządzania Vagranta;
  połączenia `vagrant ssh` przychodzą z 10.0.2.2.
- Adres hosta w sieci host-only: `common_ssh_host_address` (domyślnie 192.168.56.1).

## Dostęp administracyjny

| Konto | Skąd | Jak | ADR |
|---|---|---|---|
| `admin` → ops | host (192.168.56.1) | klucz labu `.lab/ssh/id_ed25519` | [0003](adr/0003-ops-wezel-sterujacy.md), [0005](adr/0005-bootstrap-klucze-labu.md) |
| `admin` → pozostałe | ops (192.168.56.5) | klucz labu | [0003](adr/0003-ops-wezel-sterujacy.md) |
| `vagrant` | 10.0.2.2 (NAT) | klucz Vagranta, hasło zablokowane | [0006](adr/0006-konto-vagrant.md) |
| `root` | nigdzie przez SSH | — | — |

## Firewall (nftables) — etap 1

Tabela `inet filter`, łańcuch `input` z polityką `drop`
([ADR 0004](adr/0004-firewall-nftables-porty-per-etap.md)):

| Węzły | Reguła |
|---|---|
| wszystkie | `iif lo accept`; `ct state established,related accept`; `ct state invalid drop` |
| wszystkie | `tcp dport 22` na interfejsie NAT (kanał zarządzania Vagranta) |
| ≠ ops | `tcp dport 22` z 192.168.56.5 |
| ops | `tcp dport 22` z adresu hosta (192.168.56.1) |

`forward`: `drop`, `output`: `accept`. ICMP echo zamknięty.

### Reguły kolejnych etapów (zapowiedź)

Każda rola etapu dokłada plik `/etc/nftables.d/<rola>.nft` z regułami `add rule inet filter
input ...` o źródłach wyliczanych z inventory (kontrakt
`specs/001-etap1-fundament/contracts/firewall-dropin.md`). Planowane:

| Etap | Węzły | Port | Źródła |
|---|---|---|---|
| 2 | db | 3306/tcp | web1, web2, druga baza |
| 3 | web | port aplikacji | lb1, lb2 |
| 4 | lb | 80/443/tcp | sieć labu / Internet przez tunel |
| 4 | lb | Corosync 5405/udp, pcsd 2224/tcp | drugi węzeł lb |

## Konfiguracja bazowa (rola `common`)

Kolejność (FR-018): `packages` → `users` → `hosts` → `time` → `firewall` → `ssh` → `updates`.
Interfejs roli: `specs/001-etap1-fundament/contracts/common-role.md`.
