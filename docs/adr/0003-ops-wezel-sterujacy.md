# 0003. `ops` jako węzeł sterujący; źródła ruchu SSH

- **Status**: Przyjęty
- **Data**: 2026-11-09
- **Etap**: 1

## Kontekst

Ansible nie działa natywnie na Windowsie, a host ma tylko VirtualBoxa i Vagranta. Potrzebny jest
Linux, z którego uruchamia się playbooki, i jasna odpowiedź, kto może łączyć się po SSH z kim.
Pytania Q3 (spec) i Q5 (clarify), decyzja R9.

## Decyzja

- Ansible działa na węźle `ops` (192.168.56.5), z kodem z folderu współdzielonego `/vagrant`
  (ADR 0008). `ops` konfiguruje sam siebie lokalnie (`ansible_connection: local`), bez SSH do
  samego siebie.
- Dozwolone źródła SSH w sieci labu:
  - węzły ≠ `ops`: tylko z `ops` (192.168.56.5), konto `admin`;
  - `ops`: tylko z hosta (`common_ssh_host_address`, domyślnie 192.168.56.1), konto `admin`;
  - wszędzie: konto `vagrant` tylko z kanału NAT Vagranta (10.0.2.2) — ADR 0006.
- Obrona w głąb: to samo ograniczenie egzekwują **dwie niezależne warstwy** — reguły nftables
  (`ip saddr ... tcp dport 22`) i `AllowUsers user@źródło` w `sshd_config`.

## Rozważane alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| Ansible w WSL na hoście | brak dodatkowej maszyny | ruch z hosta do wszystkich węzłów; zależność od konfiguracji WSL recenzenta | szersza powierzchnia SSH, mniej powtarzalne |
| `ansible_local` w Vagrancie | automatyczne uruchamianie | Ansible ukryty w `vagrant up`; trudno o drugi przebieg i tagi | Ansible ma być uruchamiany jawnie |
| SSH do węzłów z dowolnego adresu labu | prostsze reguły | każdy węzeł może atakować inne | sprzeczne z FR-011 |

## Konsekwencje

- **Pozytywne**: jeden punkt wejścia do zarządzania (wzorzec bastionu); test US4.3 łatwo
  sprawdza, że `web1` nie dostanie się do `db1` po SSH.
- **Negatywne / ograniczenia**: `ops` jest pojedynczym punktem awarii zarządzania (nie usług);
  dostęp do pozostałych węzłów z hosta wymaga przejścia przez `ops` (`ssh -J` lub `vagrant ssh`).
- **Co byłoby inaczej na produkcji**: bastion z MFA i nagrywaniem sesji, Ansible uruchamiany z
  potoku CI/CD (AWX/Ansible Automation Platform), klucze krótkotrwałe (certyfikaty SSH).
