# 0008. Repozytorium na `ops` przez folder współdzielony (tylko na `ops`, uprawnienia 755/644)

- **Status**: Przyjęty
- **Data**: 2026-11-09
- **Etap**: 1

## Kontekst

Kod edytowany jest na hoście, a uruchamiany na `ops` (ADR 0003). Potrzebny jest mechanizm bez
ręcznej synchronizacji. Ansible ignoruje `ansible.cfg` w katalogu z prawem zapisu dla wszystkich,
a domyślny montaż `vboxsf` ma `0777`. Clarify Q1, R6.

## Decyzja

- Katalog repo montowany jako `/vagrant` (`vboxsf`) **tylko na `ops`**; na pozostałych węzłach
  folder jest wyłączony (`disabled: true`).
- `mount_options: ["dmode=755", "fmode=644"]` — `ansible.cfg` nie jest ignorowany.
- Profil konta `admin` na `ops` ustawia `ANSIBLE_CONFIG=/vagrant/ansible.cfg` (zabezpieczenie) i
  przechodzi do `/vagrant`.
- Klucz prywatny jest kopiowany z `/vagrant/.lab/ssh/` do `~admin/.ssh/` z `0600`; SSH nigdy
  nie czyta go bezpośrednio z `vboxsf`.

## Rozważane alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| rsync (`type: rsync`) | prawdziwe uprawnienia Linuksa | trzeba pamiętać o `vagrant rsync`; praca na nieaktualnej kopii | odrzucony w clarify Q1 |
| Tylko `ANSIBLE_CONFIG` przy `0777` | działa | katalog nadal zapisywalny dla wszystkich | słabsze bezpieczeństwo |
| `git clone` z GitHuba na `ops` | jak na produkcji | każda zmiana wymaga commita i pusha przed testem | spowalnia pętlę pracy |

## Konsekwencje

- **Pozytywne**: zmiana pliku na hoście jest od razu widoczna na `ops`; pozostałe węzły nie
  widzą repo ani klucza.
- **Negatywne / ograniczenia**: na `ops` plik `/vagrant/.lab/ssh/id_ed25519` jest czytelny dla
  każdego lokalnego użytkownika (`fmode=644`). Akceptowalne w labie, bo jedyni użytkownicy `ops`
  (`admin`, `vagrant`) i tak mają sudo i dostęp do tego klucza. `vboxsf` nie ma bitu
  wykonywania — skrypty uruchamia się jawnie przez `bash`/`python3`.
- **Co byłoby inaczej na produkcji**: klucz nie leżałby w katalogu współdzielonym; kod
  pobierany z repozytorium Git przez potok CI/CD, a sekrety z menedżera sekretów.
