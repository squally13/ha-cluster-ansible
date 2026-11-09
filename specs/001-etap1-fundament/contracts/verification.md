# Kontrakt: playbook weryfikacyjny `playbooks/verify/stage1.yml`

Automatyzuje scenariusze akceptacyjne ze [spec.md](../spec.md), które da się wykonać z `ops`.
Nie jest importowany przez `site.yml` i nie zmienia trwałego stanu węzłów (tymczasowy nasłuch
jest sprzątany nawet przy błędzie — `block`/`always`).

## Wywołanie

```bash
# na ops, jako admin, w /vagrant
ansible-playbook playbooks/verify/stage1.yml            # wszystkie testy
ansible-playbook playbooks/verify/stage1.yml --tags us4 # jedna historyjka
```

Struktura: `playbooks/verify/stage1.yml` importuje `playbooks/verify/stage1/us1.yml`, `us3.yml`,
`us4.yml`, `us5.yml` (każdy z tagiem `usN`; osobne pliki, żeby historyjki nie edytowały tego
samego pliku), a sonda połączeń to `playbooks/verify/files/tcp_probe.py`.

## Testy i oczekiwane wyniki

| Tag | Scenariusz | Sprawdzenie | Wynik oczekiwany |
|---|---|---|---|
| `us1` | US1.2 | `ping` dla `all` | 7/7 `pong` |
| `us1` | US1.3 | `ansible_host` ∈ 192.168.56.0/24 i adres obecny na interfejsie węzła | 7/7 |
| `us1` | US1.4 | `getent hosts <inny węzeł>` z każdego węzła; `getent hosts $(hostname)` | adresy 192.168.56.x; nigdy `127.0.1.1` |
| `us3` | US3.2 | z `ops`: `ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no -o BatchMode=yes admin@<węzeł>` | odrzucenie, „Permission denied (publickey)” — brak `password` w metodach |
| `us3` | US3.3 | z `ops`: `ssh root@<węzeł>` kluczem labu | odrzucenie |
| `us3` | US3.4 | z `ops`: `ssh vagrant@<węzeł>` po sieci labu | odrzucenie; `passwd -S vagrant` = `L` |
| `us3` | US3.1 | `become: true` + `id` | `uid=0` |
| `us3` | US3.2–3.4, SC-004 | `sshd -T` na **7/7** węzłach (z `ops` włącznie) | `passwordauthentication no`, `kbdinteractiveauthentication no`, `permitrootlogin no`, `allowusers` = oczekiwane wpisy dla węzła — próby logowania same nie wystarczą (brak klucza labu u `root`/`vagrant`) |
| `us4` | US4.1/4.2 | nasłuch TCP 3306 na `db1`; z `web1` połączenie z timeoutem 3 s; lokalnie na `db1` | `web1`: `timeout`; lokalnie: `connected` |
| `us4` | US4.3 | z `web1`: TCP 22 na `db1` (timeout 3 s) | `timeout` |
| `us4` | US4.5 | `nft list ruleset` vs `systemctl is-enabled nftables` | polityka `drop`, `enabled` |
| `us5` | US5.1 | `chronyc tracking`: `Leap status: Normal`, \|System time\| | < 0,5 s na każdym węźle (różnica par < 1 s) |
| `us5` | US5.3 | `timedatectl show -p Timezone`; konfiguracja unattended-upgrades | `UTC` na 7/7; tylko źródła `-security`; `Automatic-Reboot "false"` |
| `us5` | US5.4 | `needrestart -b -k`; konfiguracja needrestart | kod 0, linia `NEEDRESTART-KSTA:`; `$nrconf{restart} = 'l'` |
| `us5` | US5.5 | `command -v vim htop curl rsync tcpdump` | wszystkie obecne |

Format wyniku testu połączenia (skrypt Python uruchamiany na węźle źródłowym):
`RESULT=<connected|refused|timeout> HOST=<ip> PORT=<port>`.

## Testy poza playbookiem (ręczne, z hosta — opisane w quickstart)

- US1.1, US2 (destroy/up/site ×2), US3.5 (zły szablon SSH), US4.4 (host → ops / host → inny
  węzeł), US4.6 (`vagrant ssh`, `vagrant halt`), US5.2 (przesunięcie zegara), symulacja US5.4
  (nowsze jądro — opcjonalnie), US6 (CI), US7 (tutorial).
