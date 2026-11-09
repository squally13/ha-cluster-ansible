# Data Model: Etap 1 — Fundament

Projekt nie ma bazy danych aplikacji; „dane” to deklaratywny opis infrastruktury w repozytorium.
Poniżej encje, ich źródło prawdy, pola i reguły walidacji.

## Węzeł (Node)

**Źródło prawdy**: `inventories/lab/hosts.yml` (czytany też przez `Vagrantfile`, R3).

| Pole | Typ | Przykład | Reguły |
|---|---|---|---|
| nazwa | string | `db1` | unikalna; `^[a-z][a-z0-9]*$`; zgodna z tabelą architektury |
| `ansible_host` | IPv4 | `192.168.56.31` | unikalny; w 192.168.56.0/24; różny od VIP (.10) i hosta (.1) |
| `vagrant_memory` | int (MB) | `1536` | > 0; suma dla 7 maszyn ≈ 7 GB |
| grupa | enum | `db` | dokładnie jedna z: `ops`, `lb`, `web`, `db` |
| `ansible_connection` | string | `local` | tylko dla `ops` (R5/R8: `ops` nie łączy się sam ze sobą po SSH) |

Węzły w etapie 1:

| nazwa | IP | RAM (MB) | grupa |
|---|---|---|---|
| ops | 192.168.56.5 | 1024 | ops |
| lb1 | 192.168.56.11 | 512 | lb |
| lb2 | 192.168.56.12 | 512 | lb |
| web1 | 192.168.56.21 | 1024 | web |
| web2 | 192.168.56.22 | 1024 | web |
| db1 | 192.168.56.31 | 1536 | db |
| db2 | 192.168.56.32 | 1536 | db |

**Cykl życia**: `nieistniejący` → (`vagrant up` + bootstrap) → `bootstrapped` (konto `admin`,
klucz labu) → (`site.yml`) → `skonfigurowany` → (drugi `site.yml`) → `zbieżny` (`changed=0`).
`vagrant destroy` wraca do `nieistniejący`.

## Adres VIP

| Pole | Wartość | Reguły |
|---|---|---|
| nazwa | `vip` | wpis w `/etc/hosts`; nie jest hostem inventory |
| adres | 192.168.56.10 | zmienna `common_vip_address` w `group_vars/all/main.yml` |

## Para kluczy labu

| Pole | Wartość | Reguły |
|---|---|---|
| ścieżka | `.lab/ssh/id_ed25519` (+ `.pub`) | katalog w `.gitignore`; generowana raz, używana ponownie |
| typ | ed25519, bez hasła | — |
| klucz publiczny | `authorized_keys` konta `admin` na 7 węzłach | wstrzykiwany przez bootstrap, utrzymywany przez rolę `common` |
| klucz prywatny | host + `~admin/.ssh/id_ed25519` na `ops` (`0600`) | nigdy w Git; nigdy czytany przez SSH bezpośrednio z `vboxsf` |

**Cykl życia**: brak → wygenerowana (pierwszy `vagrant up`) → używana; usunięcie `.lab/` wymaga
pełnego odtworzenia od zera.

## Konto

| Konto | Logowanie | Źródła SSH | sudo | Hasło |
|---|---|---|---|---|
| `admin` | klucz labu | węzły ≠ ops: 192.168.56.5; ops: adres hosta (domyślnie 192.168.56.1) | tak, bez hasła | brak |
| `vagrant` | klucz Vagranta | 10.0.2.2 (kanał NAT) | tak (z obrazu) | zablokowane |
| `root` | zabronione przez SSH | — | — | bez zmian |

## Reguła dostępu (firewall)

| Pole | Typ | Przykład |
|---|---|---|
| węzeł/grupa docelowa | grupa inventory | `db` |
| protokół/port | `tcp/3306` | — |
| źródło | lista IP/hostów z inventory | `web1`, `web2`, druga baza |
| etap wprowadzający | int | 2 |
| plik | ścieżka | `/etc/nftables.d/mysql.nft` |

Reguły etapu 1 (rola `common`, plik bazowy `/etc/nftables.conf`):

| Węzły | Reguła |
|---|---|
| wszystkie | `iif lo accept`; `ct state established,related accept`; `ct state invalid drop` |
| wszystkie | `tcp dport 22` na interfejsie NAT (kanał zarządzania Vagranta) |
| ≠ ops | `tcp dport 22` z 192.168.56.5 |
| ops | `tcp dport 22` z adresu hosta (`common_ssh_host_address`, domyślnie 192.168.56.1) |

Reguły kolejnych etapów: wyłącznie przez fragmenty z [contracts/firewall-dropin.md](contracts/firewall-dropin.md).

## Znacznik pierwszej aktualizacji

| Pole | Wartość | Reguły |
|---|---|---|
| ścieżka | `/var/lib/ha-homelab/initial-upgrade.done` | istnienie = pełna aktualizacja już wykonana; zadanie aktualizacji pomijane |

## ADR

| Pole | Reguły |
|---|---|
| plik | `docs/adr/NNNN-krotki-tytul.md`, numeracja rosnąca |
| sekcje | Status, Kontekst, Decyzja, Rozważane alternatywy, Konsekwencje |
| status | Proponowany → Przyjęty → (opcjonalnie) Zastąpiony przez NNNN |

ADR-y etapu 1: patrz lista w [plan.md](plan.md#adr-y-do-napisania-w-etapie-1).
