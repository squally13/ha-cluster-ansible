# 0010. MySQL 8.4 LTS z repozytorium Oracle dla Debiana 13, dokładnie przypięta łatka

- **Status**: Przyjęty
- **Data**: 2026-11-11
- **Etap**: 2

## Kontekst

Plan projektu wymaga MySQL 8.4 LTS „z oficjalnego repozytorium Oracle”, a konstytucja (zasada I)
— wersji przypiętych w repo. Debian 13 w swoich repozytoriach ma MariaDB, nie MySQL. Ryzyko braku
pakietów dla Debiana 13 zapisano już w spec etapu 1. Research etapu 2 (R1) sprawdził repozytorium
2026-11-11.

Ustalenia:

- `repo.mysql.com/apt/debian/dists/trixie` ma komponent `mysql-8.4-lts` (oraz `mysql-9.7-lts`).
- Indeks `Packages` zawiera **tylko najnowszą łatkę** (`8.4.13-1debian13`); starsze `.deb` leżą w
  `pool/`, ale `apt` ich nie widzi.
- Repozytorium podpisuje klucz `RPM-GPG-KEY-mysql-2025`
  (`BCA4 3417 C3B4 85DD 128E C6D4 B7B3 B788 A8D3 785C`), **ważny do 2027-10-23**.

## Decyzja

- Repozytorium Oracle dodawane przez rolę `mysql` bezpośrednio: klucz w
  `roles/mysql/files/mysql-2025.asc`, plik `/etc/apt/sources.list.d/mysql.sources` (deb822,
  `Signed-By`), komponent `mysql-8.4-lts`. Bez pakietu `mysql-apt-config` (interaktywny debconf).
- Wersja przypięta **dokładnie**: `mysql_version: "8.4.13-1debian13"` + `apt_preferences`
  (`Pin-Priority: 1001` dla `mysql-*`).
- Gdy Oracle wyda nową łatkę, odtworzenie od zera zatrzyma się na instalacji pakietu z błędem
  „wersja nie znaleziona”. Naprawa: podbicie `mysql_version` w `roles/mysql/defaults/main.yml`
  (jedna linia, osobny commit) i wpis w `docs/notes.md`.
- Klucz wygasa 2027-10-23 — wtedy `apt update` zgłosi błąd podpisu; naprawa: nowy klucz z
  `repo.mysql.com` w `roles/mysql/files/` (odcisk sprawdzony przez `gpg --show-keys`).

## Rozważane alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| MariaDB z Debiana 13 | w repo dystrybucji, wieloletnie wsparcie Debiana | inny produkt; GTID MariaDB niezgodny z MySQL | plan i ogłoszenie wymagają MySQL |
| MySQL 9.7 LTS | nowsza linia LTS w tym samym repo | plan przypina 8.4; mniej materiałów | zostaje jako rozszerzenie |
| `8.4.*` zamiast dokładnej łatki | odtworzenie nigdy się nie zatrzyma | dwa odtworzenia mogą dać różne wersje bez śladu w Git | sprzeczne z zasadą I |
| `.deb` z `pool/` po URL | można trzymać starą łatkę latami | ręczne rozwiązywanie ~7 zależności pakietów, brak aktualizacji bezpieczeństwa | złożoność nieproporcjonalna do labu |
| pakiet `mysql-apt-config` | oficjalna ścieżka Oracle | interaktywny debconf, sam zarządza kluczem i listą źródeł | trudny do idempotentnego użycia |

## Konsekwencje

- **Pozytywne**: każda zmiana wersji bazy jest widoczna w historii Git; wszystkie węzły i
  odtworzenia mają tę samą łatkę.
- **Negatywne / ograniczenia**: odtworzenie labu „po latach” wymaga podbicia wersji (świadomy
  koszt); aktualizacje bezpieczeństwa MySQL nie przychodzą automatycznie (unattended-upgrades
  obejmuje tylko `-security` Debiana).
- **Co byłoby inaczej na produkcji**: własne lustro repozytorium (np. Aptly, Pulp) z zamrożonymi
  migawkami, aktualizacje łatek jako zaplanowane zmiany z testem na stagingu.
