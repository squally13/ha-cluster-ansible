# 0015. Konto `root` bazy przez `auth_socket` zamiast hasła (odstępstwo od zapisu zasady IV)

- **Status**: Przyjęty
- **Data**: 2026-11-11
- **Etap**: 2

## Kontekst

Konstytucja (zasada IV) wymienia „root MySQL” wśród haseł, które MUSZĄ być w Ansible Vault.
Research R3 sprawdził skrypt instalacyjny pakietu `mysql-community-server 8.4.13-1debian13`:
przy pustej odpowiedzi debconf `root-pass` pakiet wykonuje `mysqld --initialize-insecure`,
`INSTALL PLUGIN auth_socket` i `ALTER USER 'root'@'localhost' IDENTIFIED WITH 'auth_socket'`.
Hasło `root` przy domyślnym `caching_sha2_password` ma losową sól, więc moduł Ansible nie porówna
skrótu — każdy przebieg zgłaszałby zmianę albo hasło trzeba ustawiać tylko przy tworzeniu.

## Decyzja

- `root@localhost` uwierzytelnia się **gniazdem uniksowym** (`auth_socket`): zalogować się może
  tylko systemowy `root` na węźle bazy. Konto nie ma hasła.
- Ansible łączy się przez `login_unix_socket` z `become` (`module_defaults` w
  `playbooks/db.yml`).
- Pozostałe konta (`repl`, `clone`, `app`) mają hasła w Vault (ADR 0013).
- **To świadome odstępstwo od zapisu zasady IV** (Governance konstytucji): zasada nie jest
  złamana — żaden sekret nie leży poza Vaultem — ale zmienia się jej założenie, że hasło `root`
  istnieje. Zakres: wyłącznie `root@localhost` na węzłach `db`. Plan usunięcia: brak — decyzja
  docelowa; zapisana w Complexity Tracking planu etapu 2.

## Rozważane alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| hasło `root` w Vault + `/root/.my.cnf` | dosłownie zgodne z zasadą IV | sekret w postaci jawnej na dysku węzła; `update_password: on_create` → rozjazd Vault ↔ baza po zmianie hasła | więcej sekretów, gorsza idempotencja |
| hasło w Vault, podawane w każdym zadaniu | brak pliku na węźle | `changed` przy każdym przebiegu (losowa sól) albo ustawianie tylko raz | łamie zasadę II lub nie wymusza hasła |

## Konsekwencje

- **Pozytywne**: jeden sekret mniej; konto administracyjne z natury niedostępne z sieci; brak
  fałszywych `changed`.
- **Negatywne / ograniczenia**: administrator musi mieć `sudo` na węźle bazy (w labie: konto
  `admin`); narzędzia uruchamiane jako inny użytkownik systemowy nie zalogują się jako `root`.
- **Co byłoby inaczej na produkcji**: osobne, imienne konta administratorów z uprawnieniami
  ograniczonymi do potrzeb, uwierzytelnianie przez LDAP/PAM lub krótkotrwałe poświadczenia z
  menedżera sekretów (np. Vault Database Secrets Engine).
