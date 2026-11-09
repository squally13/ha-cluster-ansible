# 0007. Aktualizacje: tylko security, bez automatycznych restartów, jednorazowy pełny upgrade

- **Status**: Przyjęty
- **Data**: 2026-11-09
- **Etap**: 1

## Kontekst

Węzły powinny dostawać poprawki bezpieczeństwa bez udziału administratora, ale niekontrolowany
restart jednego z pary HA (np. obu baz naraz) to awaria. Drugi przebieg `site.yml` musi dać
`changed=0` (zasada II), więc pełny `apt upgrade` przy każdym przebiegu odpada. Clarify Q2, R11.

## Decyzja

- `unattended-upgrades` z `Origins-Pattern` ograniczonym do `${distro_codename}-security`
  (`Debian-Security`); `Unattended-Upgrade::Automatic-Reboot "false"`; timery `apt-daily*`
  włączone.
- Sygnał „wymagany restart”: `needrestart` w trybie tylko-listy (`$nrconf{restart} = 'l'`);
  sprawdzenie `needrestart -b -k` → `NEEDRESTART-KSTA: 1` = restart niewymagany, `2`/`3` =
  wymagany (nowsze jądro).
- Jednorazowa pełna aktualizacja (`apt upgrade: dist`) przy pierwszej konfiguracji węzła,
  pomijana, gdy istnieje znacznik `/var/lib/ha-homelab/initial-upgrade.done`.

## Rozważane alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| `apt upgrade` w każdym przebiegu | zawsze najnowsze pakiety | `changed` w każdym przebiegu; nieprzewidywalne zmiany | łamie zasadę II |
| Automatyczne restarty o stałej porze | zawsze aktualne jądro | oba węzły pary mogą zrestartować się jednocześnie | ryzyko awarii HA |
| Brak automatycznych aktualizacji | pełna kontrola | luki bezpieczeństwa czekają na administratora | gorsze bezpieczeństwo |

## Konsekwencje

- **Pozytywne**: poprawki bezpieczeństwa instalują się same; restarty są świadomą decyzją.
- **Negatywne / ograniczenia**: nowe jądro działa dopiero po ręcznym restarcie; aktualizacje
  inne niż security wymagają odtworzenia węzła lub ręcznego usunięcia znacznika.
- **Co byłoby inaczej na produkcji**: okna serwisowe rozłożone w parach HA (najpierw jeden węzeł
  pary, weryfikacja, potem drugi), monitoring sygnału `needrestart`, zarządzanie poprawkami
  (np. Foreman/Landscape) i repozytorium-lustro z zatwierdzonymi pakietami.
