# Plan projektu: klaster HA w homelabie z Ansible

Nov 8, 2026 · @Arkadiusz Maciejewski

## 1. Cel i zakres projektu

W 8 tygodni budujesz od zera klaster WWW wysokiej dostępności na 7 maszynach wirtualnych, w całości postawiony jednym poleceniem `ansible-playbook site.yml`. Na koniec pokazujesz na nagraniu, że po wyłączeniu dowolnego węzła serwis dalej odpowiada.

Projekt ma udowodnić rekruterowi trzy rzeczy:

- **Umiesz administrować Linuksem w praktyce**: użytkownicy, SSH, firewall, systemd, logi, sieć.
- **Myślisz automatyzacją**: każda zmiana trafia do repozytorium i jest powtarzalna. Zero ręcznego klikania na serwerach.
- **Rozumiesz wysoką dostępność**: wiesz, co się dzieje, gdy węzeł pada, i potrafisz to zademonstrować.

### Mapowanie na wymagania z ogłoszenia

| Wymaganie z ogłoszenia | Gdzie pojawia się w projekcie |
| --- | --- |
| Linux | Wszystkie węzły (Debian 12 lub Rocky Linux 9), hardening bazowy |
| Git | Repozytorium z historią commitów, gałęzie per etap, tagi wersji |
| Ansible | Cała konfiguracja jako role, inventory, Vault na sekrety |
| MySQL | Replikacja source → replica z GTID, użytkownicy, backup przed zmianami |
| Docker | Aplikacja jako obraz kontenera uruchamiany na węzłach WWW |
| Nginx | Reverse proxy przed kontenerem aplikacji |
| HAProxy | Load balancer z health checkami backendów |
| Corosync/Pacemaker | Pływający adres VIP między dwoma węzłami HAProxy |
| Cloudflare CDN | Domena za Cloudflare, TLS, cache statycznych plików |
| Jira/Confluence | Zadania etapów jako GitHub Issues/Projects, dokumentacja jak w Confluence |
| Nagios, ELK | Poza zakresem tego planu; to kolejny projekt, który podłączysz do tej infrastruktury |

### Poza zakresem

Monitoring (Nagios), centralne logi (ELK), backupy z testem odtworzenia i hardening z HIDS to osobne projekty z portfolio. Ten klaster będzie dla nich środowiskiem, więc projektuj go tak, żeby łatwo było dodać kolejne role.

## 2. Architektura

Klaster ma trzy warstwy po dwa węzły i jedną maszynę zarządzającą. Każda warstwa przetrwa utratę jednego węzła, z wyjątkiem zapisów do bazy, które wymagają ręcznego przełączenia (sekcja 6).

&#91;embedded content: architektura klastra · 3 warstwy, 7 maszyn\]

Żądanie przechodzi przez Cloudflare i tunel do VIP, który trzyma aktywny HAProxy. HAProxy rozdziela ruch na dwa węzły WWW, a aplikacja zapisuje do `db1`, który replikuje dane na `db2`.

### Maszyny, adresy i porty

| Maszyna | IP | RAM | Rola | Porty otwarte (dla kogo) |
| --- | --- | --- | --- | --- |
| ops | 192.168.56.5 | 1 GB | Węzeł sterujący Ansible, później monitoring | 22 (host) |
| VIP | 192.168.56.10 | — | Adres usługi, zarządzany przez Pacemaker | 80 (sieć labu) |
| lb1 | 192.168.56.11 | 512 MB | HAProxy, Pacemaker, cloudflared | 22 (ops), 8404 (sieć labu), 2224/TCP i 5405/UDP (lb2) |
| lb2 | 192.168.56.12 | 512 MB | HAProxy, Pacemaker, cloudflared | 22 (ops), 8404 (sieć labu), 2224/TCP i 5405/UDP (lb1) |
| web1 | 192.168.56.21 | 1 GB | Nginx + kontener aplikacji | 22 (ops), 80 (lb1, lb2) |
| web2 | 192.168.56.22 | 1 GB | Nginx + kontener aplikacji | 22 (ops), 80 (lb1, lb2) |
| db1 | 192.168.56.31 | 1,5 GB | MySQL source | 22 (ops), 3306 (web1, web2, db2) |
| db2 | 192.168.56.32 | 1,5 GB | MySQL replica | 22 (ops), 3306 (web1, web2, db1) |

Łącznie około 7 GB RAM. Jeśli masz mniej pamięci, pomiń maszynę `ops` i uruchamiaj Ansible bezpośrednio z hosta.

## 3. Środowisko i narzędzia

Najprostszy start to Vagrant z VirtualBoxem lub libvirt na laptopie z 16 GB RAM. Cały klaster zmieści się w około 7 GB pamięci.

### Wymagania sprzętowe

| Zasób | Minimum | Komfortowo |
| --- | --- | --- |
| RAM hosta | 16 GB | 32 GB |
| CPU hosta | 4 rdzenie | 8 rdzeni lub wątków |
| Dysk | 60 GB wolnego SSD | 100 GB SSD |

### Gdzie uruchomić maszyny

| Opcja | Zalety | Wady | Dla kogo |
| --- | --- | --- | --- |
| Vagrant + VirtualBox/libvirt | `Vagrantfile` w repo, każdy odtworzy środowisko jednym `vagrant up` | Wolniejsze, zależne od laptopa | Najlepszy wybór do portfolio |
| Proxmox na starym PC | Prawdziwy hypervisor, plus do CV (wirtualizacja z ogłoszenia) | Trzeba mieć osobny sprzęt | Jeśli masz wolny komputer |
| Multipass | Bardzo szybki start | Tylko Ubuntu, słabsza kontrola sieci | Do szybkich testów |
| Mały VPS (Hetzner, OVH) | Publiczny IP, prawdziwy Cloudflare | Koszt kilkudziesięciu zł miesięcznie, VIP trudniejszy | Opcjonalnie na etap 5 |

Rekomendacja: Vagrant jako baza (rekruter może sam odpalić projekt), a jeśli masz sprzęt, dodatkowo Proxmox i opis w README, jak przenieść inventory na prawdziwe maszyny.

### Wersje oprogramowania

Przypnij wersje w repo, żeby projekt działał za rok tak samo jak dziś.

- System: Debian 12 (bookworm) albo Rocky Linux 9. Wybierz jeden i trzymaj się go.
- Ansible: ansible-core 2.17 lub nowszy, kolekcje w `requirements.yml` z wersjami.
- MySQL 8.4 LTS z oficjalnego repozytorium Oracle.
- HAProxy 2.8 LTS, Nginx z repo systemowego, Pacemaker 2.1 + Corosync 3 + `pcs`.
- Docker Engine z oficjalnego repozytorium Dockera (nie z pakietu dystrybucji).

### Narzędzia na twoim komputerze

- `git`, `ansible`, `ansible-lint`, `yamllint`, `vagrant`.
- `pre-commit` z hookami lintów, żeby zepsuty YAML nie trafiał do repo.
- `asciinema` i opcjonalnie `agg` do zamiany nagrań na GIF.
- Edytor z wtyczką do Ansible (VS Code + Red Hat Ansible).

## 4. Struktura repozytorium i ról Ansible

Jedno repozytorium `ha-homelab` z rolami w katalogu `roles/`, jednym playbookiem głównym i osobnymi playbookami do testów awarii. Taki układ wygląda jak firmowe repo infrastruktury i łatwo się go czyta.

```text
ha-homelab/
├── README.md
├── Vagrantfile
├── ansible.cfg
├── requirements.yml            # kolekcje: community.mysql, community.docker, ansible.posix
├── inventories/
│   └── lab/
│       ├── hosts.yml
│       ├── group_vars/
│       │   ├── all/
│       │   │   ├── main.yml
│       │   │   └── vault.yml   # zaszyfrowany ansible-vault
│       │   ├── lb.yml
│       │   ├── web.yml
│       │   └── db.yml
│       └── host_vars/
├── roles/
│   ├── common/        # pakiety, użytkownicy, SSH, czas, firewall
│   ├── docker/
│   ├── app/           # kontener aplikacji + systemd/compose
│   ├── nginx/
│   ├── mysql/
│   ├── mysql_replication/
│   ├── haproxy/
│   └── pacemaker/
├── playbooks/
│   ├── site.yml       # importuje wszystkie poniższe
│   ├── db.yml
│   ├── web.yml
│   ├── lb.yml
│   └── chaos/         # scenariusze awarii (etap 6)
├── app/               # kod aplikacji + Dockerfile
├── docs/
│   ├── architecture.md
│   ├── runbooks/
│   └── img/
└── .github/workflows/lint.yml
```

### Konwencje, których się trzymasz

- **Idempotencja**: drugi przebieg `site.yml` musi dać `changed=0`. Sprawdzaj to po każdym etapie, bo to pierwsze, na co patrzy doświadczony admin.
- **Zmienne z prefiksem roli** (`haproxy_maxconn`, `mysql_server_id`), domyślne w `defaults/main.yml`, nadpisywane w `group_vars`.
- **Szablony zamiast `lineinfile`**: całe pliki konfiguracyjne w `templates/*.j2` z nagłówkiem „Zarządzane przez Ansible”.
- **Handlery** do restartów i przeładowań; nigdy bezwarunkowy restart w zadaniu.
- **Walidacja przed przeładowaniem**: `validate: haproxy -c -f %s` i `nginx -t`, żeby zły szablon nie położył usługi.
- **Tagi** na rolach (`--tags haproxy`), żeby można było wdrażać jedną warstwę.

### Sekrety

Wszystkie hasła (root MySQL, użytkownik replikacji, hasło `hacluster`, token Cloudflare) trzymasz w `vault.yml` zaszyfrowanym `ansible-vault`. W `main.yml` odwołujesz się do nich przez zmienne typu `mysql_root_password: "{{ vault_mysql_root_password }}"`. Plik z hasłem do vaulta dodajesz do `.gitignore`, a w README opisujesz, jak go utworzyć.

### Git

- Gałąź `main` zawsze działa; każdy etap na osobnej gałęzi i pull request do `main` (sam sobie, ale z opisem).
- Małe commity z sensownymi opisami, np. `haproxy: add health check on /healthz`.
- Tag `v1.0` po zakończeniu projektu.
- GitHub Actions uruchamia `yamllint` i `ansible-lint` na każdym pushu.

## 5. Etap 1: fundament (tydzień 1)

Po tym etapie masz 7 maszyn uruchamianych `vagrant up` i rolę `common`, która doprowadza każdą z nich do tego samego, bezpiecznego stanu bazowego.

### Kroki

1. Napisz `Vagrantfile` z pętlą po liście maszyn (nazwa, IP, RAM). Sieć prywatna `192.168.56.0/24`.
2. Utwórz `inventories/lab/hosts.yml` z grupami `lb`, `web`, `db` i `ops`.
3. Sprawdź łączność: `ansible all -m ping`.
4. Napisz rolę `common`:
   - aktualizacja pakietów i instalacja podstaw (`vim`, `htop`, `curl`, `chrony`, `rsync`, `tcpdump`);
   - użytkownik `admin` z kluczem SSH i `sudo`;
   - `sshd_config` z szablonu: `PasswordAuthentication no`, `PermitRootLogin no`, walidacja `sshd -t`;
   - strefa czasowa i synchronizacja czasu przez `chrony` (Corosync i replikacja MySQL nie lubią rozjechanego zegara);
   - `/etc/hosts` generowany z inventory, żeby węzły widziały się po nazwach;
   - firewall (`nftables` albo `firewalld`) z domyślną polityką drop i otwartymi tylko portami z tabeli w sekcji 2;
   - `unattended-upgrades` lub `dnf-automatic` tylko dla poprawek bezpieczeństwa.
5. Uruchom `site.yml` dwa razy. Drugi przebieg musi zakończyć się `changed=0`.
6. Dodaj workflow GitHub Actions z `yamllint` i `ansible-lint`.

### Fragment, od którego zaczniesz

```yaml
# roles/common/tasks/ssh.yml
- name: Konfiguracja sshd z szablonu
  ansible.builtin.template:
    src: sshd_config.j2
    dest: /etc/ssh/sshd_config
    owner: root
    mode: "0600"
    validate: /usr/sbin/sshd -t -f %s
  notify: Restart sshd
```

### Kryterium ukończenia

- [ ] `vagrant destroy -f && vagrant up && ansible-playbook playbooks/site.yml` działa bez błędów.
- [ ] Drugi przebieg daje `changed=0`.
- [ ] Logowanie hasłem i jako root jest zablokowane.
- [ ] Z `web1` nie da się połączyć z portem 3306 na `db1` (firewall jeszcze go nie otwiera).
- [ ] Lint w GitHub Actions jest zielony.

## 6. Etap 2: MySQL source → replica z GTID (tydzień 2)

Po tym etapie `db1` przyjmuje zapisy, a `db2` jest repliką tylko do odczytu, która nadąża za `db1` z opóźnieniem bliskim zera. Całość konfiguruje Ansible, bez ręcznego `CHANGE REPLICATION SOURCE`.

### Kroki

1. Rola `mysql`: repozytorium Oracle, instalacja MySQL 8.4, `my.cnf` z szablonu, usunięcie anonimowych kont i testowej bazy (to, co robi `mysql_secure_installation`, ale idempotentnie).
2. Unikalny `server_id` dla każdego węzła z `host_vars`.
3. W `my.cnf` włącz GTID i binlogi:

```ini
[mysqld]
server_id                = {{ mysql_server_id }}
bind-address             = {{ ansible_host }}
gtid_mode                = ON
enforce_gtid_consistency = ON
log_bin                  = mysql-bin
binlog_format            = ROW
relay_log                = relay-bin
{% if mysql_role == 'replica' %}
read_only                = ON
super_read_only          = ON
{% endif %}
```

4. Rola `mysql_replication`: na `db1` tworzy użytkownika `repl` z uprawnieniem `REPLICATION SLAVE` dostępnego tylko z IP `db2`.
5. Na `db2` moduł `community.mysql.mysql_replication` z `mode: changereplication` (`SOURCE_AUTO_POSITION=1`) i `mode: startreplica`. Zadanie wykonuj warunkowo, tylko gdy replikacja nie jest jeszcze skonfigurowana (`getreplica`).
6. Utwórz bazę aplikacji `app` i użytkownika `app` z dostępem tylko z adresów `web1` i `web2`.
7. Firewall: port 3306 na `db1` i `db2` otwarty tylko dla sieci węzłów WWW i drugiego węzła bazy.

### Weryfikacja

```sql
-- na db2
SHOW REPLICA STATUS\G
-- oczekujesz: Replica_IO_Running: Yes, Replica_SQL_Running: Yes, Seconds_Behind_Source: 0
```

Test praktyczny: wstaw wiersz na `db1`, odczytaj go na `db2`. Spróbuj zapisu na `db2`: musi zakończyć się błędem przez `super_read_only`.

### Decyzja do opisania w README

Ten projekt nie robi automatycznego przełączenia bazy (failover MySQL). Zapisz to wprost: failover bazy jest ręczny i opisany w runbooku `docs/runbooks/mysql-promote-replica.md`. Rekruter doceni, że świadomie znasz granice projektu. Automatyczny failover (Orchestrator, MySQL InnoDB Cluster albo Pacemaker z agentem MySQL) wpisz jako rozszerzenie w sekcji 13.

### Kryterium ukończenia

- [ ] Replikacja działa po `vagrant destroy` i ponownym `site.yml`.
- [ ] Drugi przebieg daje `changed=0` (nie resetujesz replikacji przy każdym uruchomieniu).
- [ ] Runbook promowania repliki przetestowany ręcznie choć raz.

## 7. Etap 3: aplikacja w Dockerze + Nginx (tydzień 3)

Po tym etapie na `web1` i `web2` działa ta sama aplikacja w kontenerze, za Nginxem, z endpointem `/healthz` sprawdzającym też połączenie z bazą. Odpowiedź zawiera nazwę hosta, dzięki czemu na demo widać, który węzeł obsłużył żądanie.

### Aplikacja

Wystarczy małe API w Pythonie (Flask lub FastAPI) z trzema endpointami:

| Endpoint | Co robi | Po co |
| --- | --- | --- |
| `GET /` | Zwraca JSON z nazwą hosta i licznikiem odwiedzin z MySQL | Widać rozkład ruchu i działanie bazy |
| `GET /healthz` | 200, gdy aplikacja i baza odpowiadają; 503 w przeciwnym razie | Health check dla HAProxy |
| `POST /visit` | Zapisuje wizytę do tabeli na `db1` | Pokazuje zapisy na source |

Kod i `Dockerfile` trzymasz w katalogu `app/`. Użyj obrazu `python:3.12-slim`, uruchamiaj proces jako użytkownik bez roota i dodaj instrukcję `HEALTHCHECK`.

### Kroki

1. Rola `docker`: oficjalne repozytorium, instalacja Docker Engine, dodanie użytkownika `admin` do grupy `docker`.
2. Obraz budujesz w GitHub Actions i publikujesz w GitHub Container Registry (`ghcr.io`). Węzły tylko pobierają gotowy obraz o konkretnym tagu (nie `latest`).
3. Rola `app`: moduł `community.docker.docker_container` uruchamia kontener z `restart_policy: unless-stopped`, port tylko na `127.0.0.1:8000`, dane do bazy przez zmienne środowiskowe z Vaulta.
4. Rola `nginx`: vhost jako reverse proxy na `127.0.0.1:8000`, własny format logu z czasem odpowiedzi (`$request_time`, `$upstream_response_time`) pod przyszły projekt z ELK.
5. Nginx przekazuje nagłówki `X-Forwarded-For` i `X-Real-IP`, a w `set_real_ip_from` ufa tylko adresom HAProxy.
6. Firewall: port 80 na węzłach WWW otwarty tylko dla `lb1`, `lb2` i adresu VIP.

### Fragment vhosta

```nginx
upstream app {
    server 127.0.0.1:8000;
    keepalive 16;
}

server {
    listen 80 default_server;
    server_name _;

    set_real_ip_from 192.168.56.11;
    set_real_ip_from 192.168.56.12;
    real_ip_header   X-Forwarded-For;

    location / {
        proxy_pass http://app;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

### Kryterium ukończenia

- [ ] `curl http://web1/` i `curl http://web2/` zwracają różne nazwy hosta i ten sam licznik z bazy.
- [ ] Po zatrzymaniu MySQL na `db1` endpoint `/healthz` zwraca 503.
- [ ] Zmiana tagu obrazu w `group_vars` i ponowny `site.yml` wdrażają nową wersję.

## 8. Etap 4: HAProxy + Corosync/Pacemaker z VIP (tygodnie 4–5)

To serce projektu i najtrudniejszy etap, dlatego ma dwa tygodnie. Na końcu ruch trafia na adres VIP `192.168.56.10`, który Pacemaker trzyma na jednym z węzłów `lb1`/`lb2` i przenosi w kilka sekund, gdy ten węzeł padnie.

### Część A: HAProxy (tydzień 4)

1. Rola `haproxy`: instalacja wersji 2.8 LTS, `haproxy.cfg` z szablonu z walidacją `haproxy -c -f %s`.
2. Backend z health checkiem na `/healthz` i równym rozkładem ruchu.
3. Strona statystyk na porcie 8404, dostępna tylko z sieci labu, z hasłem z Vaulta.
4. Sysctl `net.ipv4.ip_nonlocal_bind = 1`, żeby HAProxy na węźle zapasowym mógł nasłuchiwać na VIP, którego jeszcze nie ma.
5. Usługa `haproxy` w systemd ma być **wyłączona z autostartu**: od teraz uruchamia ją Pacemaker.

```text
frontend fe_http
    bind 192.168.56.10:80
    default_backend be_web

backend be_web
    balance roundrobin
    option httpchk
    http-check send meth GET uri /healthz
    http-check expect status 200
    option forwardfor
    server web1 192.168.56.21:80 check inter 2s fall 3 rise 2
    server web2 192.168.56.22:80 check inter 2s fall 3 rise 2

listen stats
    bind 0.0.0.0:8404
    stats enable
    stats uri /
    stats auth admin:{{ haproxy_stats_password }}
```

### Część B: Corosync/Pacemaker (tydzień 5)

1. Rola `pacemaker`: pakiety `pacemaker`, `corosync`, `pcs`, `resource-agents`, hasło użytkownika `hacluster` z Vaulta, usługa `pcsd` włączona.
2. Firewall między `lb1` i `lb2`: TCP 2224 (pcsd) oraz UDP 5405 (Corosync).
3. Konfiguracja klastra przez `pcs`, uruchamiana tylko na jednym węźle (`run_once: true`) i chroniona warunkami, żeby była idempotentna:

```bash
pcs host auth lb1 lb2 -u hacluster -p "$HACLUSTER_PASSWORD"
pcs cluster setup lbcluster lb1 lb2 --start --enable
pcs property set stonith-enabled=false   # tylko w labie, patrz niżej
pcs resource create vip ocf:heartbeat:IPaddr2 \
    ip=192.168.56.10 cidr_netmask=24 op monitor interval=10s
pcs resource create haproxy systemd:haproxy \
    op monitor interval=10s clone
pcs constraint colocation add vip with haproxy-clone INFINITY
pcs constraint order haproxy-clone then vip
```

4. W Ansible każde polecenie `pcs` opakuj w `ansible.builtin.command` z warunkiem: najpierw zadanie sprawdzające (np. `pcs resource config vip`), potem tworzenie tylko wtedy, gdy zasób nie istnieje. Pisanie tego samodzielnie jest świetną nauką idempotencji. Jako punkt odniesienia możesz przejrzeć rolę `ha_cluster` z Linux System Roles.

### Dwa tematy, które musisz rozumieć i opisać

- **Quorum przy dwóch węzłach.** `pcs cluster setup` dla dwóch węzłów włącza `two_node: 1` w Corosync. Klaster działa wtedy na jednym węźle, ale grozi split-brain, gdy węzły stracą łączność między sobą, a oba żyją.
- **Fencing (STONITH).** Wyłączasz go w labie, bo nie masz fizycznego mechanizmu odcięcia węzła. W README napisz wprost, że na produkcji to niedopuszczalne, i podaj, czego byś użył: `fence_ipmilan` na fizycznych serwerach, `fence_virsh` lub `fence_pve` na wirtualizacji, ewentualnie SBD. Na rozmowie to pytanie pada prawie zawsze.

### Kryterium ukończenia

- [ ] `pcs status` pokazuje oba węzły online, VIP na jednym z nich, HAProxy na obu.
- [ ] `curl http://192.168.56.10/` naprzemiennie zwraca `web1` i `web2`.
- [ ] `pcs node standby lb1` przenosi VIP na `lb2` w mniej niż 10 sekund.
- [ ] Ponowny `site.yml` nie zmienia konfiguracji klastra (`changed=0`).

## 9. Etap 5: Cloudflare i TLS (tydzień 6)

Twój lab nie ma publicznego IP, więc podłączasz go do Cloudflare przez **Cloudflare Tunnel** (`cloudflared`). Tunel zestawia połączenie wychodzące, nie wymaga otwierania portów na routerze i działa w darmowym planie. Potrzebujesz tylko własnej domeny.

### Kroki

1. Kup domenę (np. `.pl` lub `.dev`) i przenieś jej serwery DNS do Cloudflare (darmowy plan).
2. Utwórz tunel i wygeneruj jego token. Token trafia do Vaulta.
3. Rola `cloudflared` instaluje usługę na **obu** węzłach `lb1` i `lb2`. Tunel z dwoma konektorami jest odporny na awarię jednego z nich, więc Cloudflare nie staje się nowym pojedynczym punktem awarii.
4. Tunel kieruje ruch z `app.twojadomena.pl` na `http://192.168.56.10` (VIP).
5. Szyfrowanie: Cloudflare kończy TLS dla odwiedzających, a tunel jest szyfrowany do `cloudflared`. W README opisz, jak wyglądałaby wersja bez tunelu: publiczny IP, certyfikat Cloudflare Origin CA na HAProxy i tryb SSL **Full (strict)**.
6. Prawdziwy adres klienta: Cloudflare dodaje nagłówek `CF-Connecting-IP`. Przekaż go przez HAProxy do Nginxa i loguj go zamiast adresu tunelu.
7. Reguła cache dla `/static/*` (długi TTL), a dla `/` i API brak cache. Sprawdź nagłówek odpowiedzi `cf-cache-status`: `HIT` dla statyk, `DYNAMIC` lub `BYPASS` dla API.
8. Włącz w Cloudflare: **Always Use HTTPS**, minimalną wersję TLS 1.2 i podstawowe reguły WAF dostępne w darmowym planie.

### Opcjonalnie: Cloudflare jako kod

Zamiast klikać w panelu, opisz rekordy DNS i reguły cache w Terraformie (provider `cloudflare/cloudflare`) w katalogu `terraform/`. To jedno zadanie więcej, ale pokazuje podejście infrastructure as code także poza serwerami.

### Kryterium ukończenia

- [ ] `https://app.twojadomena.pl/` działa z publicznego internetu z ważnym certyfikatem.
- [ ] Zatrzymanie `cloudflared` na jednym węźle nie przerywa dostępu.
- [ ] Logi Nginxa pokazują prawdziwe IP odwiedzających.
- [ ] Statyki mają `cf-cache-status: HIT` przy drugim żądaniu.

Jeśli nie chcesz kupować domeny, pomiń ten etap i dopisz go jako rozszerzenie. Reszta projektu działa bez niego.

## 10. Etap 6: testy failoveru i scenariusze awarii (tydzień 7)

Ten etap zamienia „zbudowałem klaster” w „udowodniłem, że klaster działa”. Dla każdego scenariusza mierzysz, ile żądań się nie udało i jak długo trwał przestój, a wyniki wpisujesz do README.

### Narzędzie pomiarowe

Prosty skrypt `tools/probe.sh` wysyła żądanie co 0,2 sekundy i wypisuje znacznik czasu, kod HTTP i nazwę hosta, który odpowiedział. Uruchamiasz go w jednym oknie, a awarię wywołujesz w drugim.

```bash
#!/usr/bin/env bash
URL="${1:-http://192.168.56.10/}"
while true; do
  out=$(curl -s -m 1 -o /tmp/body -w '%{http_code}' "$URL")
  host=$(jq -r .host /tmp/body 2>/dev/null)
  echo "$(date +%T.%3N) $out ${host:--}"
  sleep 0.2
done
```

### Scenariusze

| # | Scenariusz | Jak wywołać | Oczekiwany wynik |
| --- | --- | --- | --- |
| 1 | Awaria węzła WWW | `vagrant halt web1` | HAProxy wyklucza `web1` po ok. 6 s (3 × 2 s); cały ruch idzie na `web2` |
| 2 | Awaria kontenera aplikacji | `docker stop app` na `web2` | `/healthz` przestaje odpowiadać, backend wypada z puli |
| 3 | Planowane przełączenie LB | `pcs node standby lb1` | VIP przechodzi na `lb2`, zero lub kilka nieudanych żądań |
| 4 | Twarda awaria aktywnego LB | `vagrant halt --force lb1` | VIP na `lb2` po kilku–kilkunastu sekundach (monitor + timeout Corosync) |
| 5 | Awaria procesu HAProxy | `kill -9` procesu HAProxy na aktywnym węźle | Pacemaker restartuje usługę albo przenosi VIP |
| 6 | Awaria repliki bazy | `systemctl stop mysql` na `db2` | Serwis działa; po starcie `db2` replikacja nadrabia zaległości |
| 7 | Awaria source bazy | `systemctl stop mysql` na `db1` | Zapisy przestają działać; ręczne promowanie `db2` według runbooka |
| 8 | Powrót węzła | Uruchom ponownie zatrzymany węzeł | Węzeł wraca do puli lub klastra bez ręcznej ingerencji |

Scenariusz 7 jest celowo „niezaliczony” przez automat. Pokaż go uczciwie i odsyłaj do runbooka. To lepsze niż udawanie, że wszystko jest automatyczne.

### Automatyzacja testów

Scenariusze 1–5 zapisz jako playbooki w `playbooks/chaos/`, np. `chaos/kill-active-lb.yml`: ustala, na którym węźle jest VIP, zatrzymuje go, czeka i sprawdza modułem `uri`, że VIP dalej odpowiada. Dzięki temu każdy, kto sklonuje repo, może sam powtórzyć test.

### Nagrania

- Nagraj scenariusze 3 i 4 przez `asciinema` z podzielonym terminalem (`tmux`): po lewej `probe.sh`, po prawej polecenie awarii i `pcs status`.
- Zamień nagranie na GIF (`agg`) i wstaw na górę README. Ten jeden GIF jest najważniejszym elementem całego portfolio.
- Do każdego scenariusza dopisz w README zmierzony wynik, np. „Hard failover lb1: 2 nieudane żądania, 9 s przerwy”.

### Kryterium ukończenia

- [ ] Wszystkie 8 scenariuszy wykonane i opisane z wynikami.
- [ ] Co najmniej 3 playbooki w `playbooks/chaos/`.
- [ ] GIF z failoverem w README.

## 11. README i prezentacja projektu (tydzień 8)

Rekruter poświęci na repozytorium 2–3 minuty, więc README musi w tym czasie pokazać, co zbudowałeś i że to działa. Kod przeczyta dopiero inżynier na rozmowie technicznej.

### Układ README

1. **Tytuł i jedno zdanie**: „Klaster WWW wysokiej dostępności (HAProxy + Pacemaker, Nginx, Docker, MySQL z replikacją) postawiony w całości z Ansible”.
2. **GIF z failoverem** zaraz pod tytułem.
3. **Diagram architektury** (ten z sekcji 2, wyeksportowany do PNG lub narysowany w draw.io albo Mermaid).
4. **Szybki start**: 4–5 poleceń od `git clone` do działającego klastra, z wymaganiami sprzętowymi.
5. **Co jest w środku**: tabela ról z jednym zdaniem opisu każdej.
6. **Wyniki testów awarii**: tabela scenariuszy z sekcji 10 z twoimi zmierzonymi czasami.
7. **Decyzje projektowe**: dlaczego Pacemaker, a nie keepalived; dlaczego replikacja asynchroniczna; dlaczego STONITH wyłączony w labie.
8. **Ograniczenia i co zrobiłbym na produkcji**: fencing, automatyczny failover bazy, monitoring, backupy, osobna sieć dla Corosync.
9. **Czego się nauczyłem**: 3–5 konkretnych problemów, które napotkałeś, i jak je rozwiązałeś.

### Dokumentacja w `docs/`

Traktuj katalog `docs/` jak przestrzeń w Confluence:

- `architecture.md`: opis warstw, adresacja, porty, przepływ ruchu.
- `runbooks/mysql-promote-replica.md`: promowanie repliki krok po kroku, z poleceniami i sposobem weryfikacji.
- `runbooks/add-web-node.md`: dodanie trzeciego węzła WWW (inventory, `site.yml --limit`, weryfikacja w statystykach HAProxy).
- `runbooks/pacemaker-maintenance.md`: aktualizacja węzła LB bez przestoju (`standby`, aktualizacja, `unstandby`).
- `postmortems/`: jeden lub dwa postmortemy z prawdziwych problemów podczas budowy, z osią czasu, przyczyną i wnioskami.

### Planowanie jak w Jirze

Załóż GitHub Project z tablicą Kanban i Issues dla każdego zadania z etapów. Pull requesty linkuj do Issues (`Closes #12`). To pokazuje, że umiesz pracować w procesie podobnym do Jira, i daje rekruterowi historię pracy.

### Na koniec

- Przypnij repozytorium na profilu GitHub i dodaj tematy (`ansible`, `haproxy`, `pacemaker`, `high-availability`, `homelab`).
- Napisz krótki wpis na LinkedIn albo blogu z GIF-em i linkiem do repo.
- Poproś kogoś o sklonowanie repo i uruchomienie według README. Każde miejsce, w którym utknie, to błąd w dokumentacji.

## 12. Harmonogram i kamienie milowe

Całość zajmie około 8 tygodni przy 8–10 godzinach tygodniowo, czyli 65–80 godzin pracy. Jeśli masz mniej czasu, rozciągnij harmonogram, ale nie pomijaj etapu 6: to on daje największą wartość w portfolio.

&#91;embedded content: harmonogram · 8 tygodni, 6 etapów, 3 kamienie milowe\]

Każdy kamień milowy to tag w Git (`m1`, `m2`, `v1.0`), dzięki czemu w historii repozytorium widać postęp.

### Zasady pracy

- Każdy etap kończysz dopiero, gdy spełnia swoje kryterium ukończenia i całość da się odtworzyć od zera (`vagrant destroy` + `site.yml`).
- Notatki z problemów prowadź od pierwszego dnia w `docs/notes.md`. Na końcu zamienisz je w sekcję „Czego się nauczyłem” i postmortemy.
- Jeśli utkniesz na dłużej niż 2 godziny, zapisz problem jako Issue z tym, co już sprawdziłeś. Często samo opisanie pomaga go rozwiązać.
- Opublikuj repozytorium od pierwszego tygodnia. Regularne commity przez 2 miesiące wyglądają lepiej niż jeden duży push na koniec.

## 13. Typowe problemy, debugowanie i rozszerzenia

Większość czasu w tym projekcie zajmie ci debugowanie, nie pisanie konfiguracji. To dobrze: każdy rozwiązany problem to historia na rozmowę kwalifikacyjną. Zapisuj je na bieżąco.

### Typowe problemy

| Objaw | Prawdopodobna przyczyna | Jak sprawdzić |
| --- | --- | --- |
| HAProxy nie startuje na węźle zapasowym | Brak `ip_nonlocal_bind`, VIP nie istnieje na tym węźle | `sysctl net.ipv4.ip_nonlocal_bind`, `journalctl -u haproxy` |
| Węzły Corosync się nie widzą | Firewall blokuje UDP 5405 albo Vagrant dał obu węzłom ten sam adres NAT | `corosync-cfgtool -s`, `ss -ulpn` |
| Corosync używa złej sieci | Nazwa hosta rozwiązuje się na `127.0.1.1` lub adres NAT | `getent hosts lb1`, popraw `/etc/hosts` |
| VIP zmienia węzeł, ale klienci go nie widzą | Nieaktualna tablica ARP w sieci | `arping`, `ip neigh` po stronie klienta |
| Replikacja stoi z błędem 1236 lub 1062 | Brak binlogów na source albo zapis na replice | `SHOW REPLICA STATUS\G`, pole `Last_SQL_Error` |
| Wszystkie backendy DOWN w HAProxy | Health check nie przechodzi, np. baza nie odpowiada albo firewall | Strona statystyk, `curl -v http://web1/healthz` z `lb1` |
| Drugi przebieg Ansible pokazuje `changed` | Zadanie `command` bez `changed_when` albo `creates` | `ansible-playbook --diff --check` |
| Zegar węzłów się rozjechał po uśpieniu laptopa | VM po wznowieniu ma stary czas | `chronyc tracking` |

### Pułapka warta opisania

`/healthz` sprawdza połączenie z bazą, więc gdy `db1` padnie, oba backendy wypadną z puli i użytkownik dostanie 503 z HAProxy. Zastanów się i opisz w README, czy to pożądane. Typowe rozwiązanie to dwa endpointy: `/livez` (sam proces aplikacji, dla HAProxy) i `/readyz` (pełna gotowość z bazą, dla monitoringu). Taka analiza bardzo dobrze wypada na rozmowie.

### Metoda debugowania, którą warto pokazać

1. Idź warstwami od klienta: DNS → VIP → HAProxy → Nginx → kontener → baza.
2. Na każdej warstwie zadaj trzy pytania: czy proces działa (`systemctl status`), czy nasłuchuje (`ss -tlpn`), czy ruch dochodzi (`tcpdump -i any port 80`).
3. Czytaj logi właściwej usługi: `journalctl -u <usługa> -f`, `/var/log/haproxy.log`, `docker logs app`.
4. Zmieniaj jedną rzecz na raz i zapisuj, co zrobiłeś.

### Rozszerzenia po ukończeniu

Każde z nich może być osobnym projektem w portfolio, podłączonym do tej samej infrastruktury:

- **Monitoring w Nagiosie** na maszynie `ops` z własnymi pluginami: opóźnienie replikacji, stan zasobów Pacemakera, liczba aktywnych backendów HAProxy.
- **ELK**: Filebeat na węzłach WWW i LB, dashboard w Kibanie z kodami HTTP i czasami odpowiedzi.
- **Backupy MySQL** z rotacją i automatycznym testem odtworzenia.
- **Hardening i HIDS** (Wazuh) jako dodatkowa rola Ansible z testami w Molecule.
- **Automatyczny failover bazy**: MySQL InnoDB Cluster z MySQL Router albo Orchestrator.
- **CI/CD**: GitHub Actions buduje obraz i wdraża go przez Ansible metodą rolling update, węzeł po węźle, z wyłączaniem backendu w HAProxy na czas aktualizacji.

## 14. Pytania rekrutacyjne, na które projekt cię przygotowuje

Po ukończeniu projektu powinieneś umieć odpowiedzieć na każde z tych pytań własnymi słowami, odwołując się do tego, co zrobiłeś. Przed rozmową przeczytaj je na głos i odpowiedz bez zaglądania do notatek.

### Wysoka dostępność

- Czym różni się Pacemaker od keepalived i kiedy wybrałbyś każdy z nich?
- Czym jest quorum i co się dzieje w klastrze dwuwęzłowym, gdy węzły stracą łączność?
- Czym jest split-brain i do czego służy fencing (STONITH)?
- Jak działa przeniesienie adresu VIP i po co jest gratuitous ARP?
- Co oznaczają parametry `inter`, `fall` i `rise` w health checku HAProxy?

### Load balancing i proxy

- Jakie znasz algorytmy równoważenia ruchu i czym różnią się tryby L4 i L7?
- Skąd aplikacja za proxy wie, jaki jest prawdziwy adres klienta?
- Gdzie w twoim układzie kończy się TLS i dlaczego tam?

### Bazy danych

- Czym jest GTID i co upraszcza w replikacji?
- Replikacja asynchroniczna a semisynchroniczna: jakie dane możesz stracić w każdej z nich?
- Jak promujesz replikę na source i o czym trzeba pamiętać po stronie aplikacji?
- Dlaczego replika to nie backup?

### Ansible i automatyzacja

- Co to jest idempotencja i jak ją sprawdzasz?
- Czym różni się handler od zwykłego zadania?
- Jak przechowujesz sekrety w repozytorium?
- Jak wdrożyć zmianę tylko na jednym węźle albo tylko jednej warstwie?

### Linux, Docker i bezpieczeństwo

- Jak sprawdzisz, czy usługa nasłuchuje i czy ruch do niej dochodzi?
- Dlaczego kontener nie powinien działać jako root i dlaczego port aplikacji jest zbindowany tylko na `127.0.0.1`?
- Jakie porty otworzyłeś na każdej warstwie i dlaczego tylko te?

### Pytanie, które pada zawsze

„Opowiedz o najtrudniejszym problemie, który rozwiązałeś w tym projekcie.” Przygotuj jedną historię w układzie: objaw, hipotezy, jak je sprawdzałeś, przyczyna, naprawa, czego się nauczyłeś. Twoje notatki z debugowania i postmortemy z `docs/` są gotowym materiałem na tę odpowiedź.
