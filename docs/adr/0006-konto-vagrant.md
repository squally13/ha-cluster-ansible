# 0006. Konto `vagrant`: zostaje, hasło zablokowane, SSH tylko z kanału NAT

- **Status**: Przyjęty
- **Data**: 2026-11-09
- **Etap**: 1

## Kontekst

Vagrant zarządza maszynami przez konto `vagrant` (ma ono znane publicznie hasło `vagrant` i
sudo). Usunięcie konta psuje `vagrant ssh`, `vagrant halt` i provisionery; pozostawienie go bez
ograniczeń to furtka w sieci labu. Clarify Q4, FR-008a.

## Decyzja

- Konto `vagrant` zostaje.
- Hasło konta jest blokowane (`ansible.builtin.user: password_lock: true`) — logowanie tylko
  kluczem Vagranta.
- `sshd_config`: `AllowUsers ... vagrant@10.0.2.2` — logowanie jako `vagrant` tylko z bramy NAT
  VirtualBoxa, czyli przez przekierowanie portu, którego używa `vagrant ssh`.
- Firewall dopuszcza port 22 na interfejsie NAT (interfejs trasy domyślnej) — ADR 0004.

## Rozważane alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| Usunąć konto `vagrant` | najczystsze | psuje `vagrant ssh`/`halt`/`reload` (US4.6) | lab musi być zarządzalny Vagrantem |
| Zostawić bez zmian | zero pracy | znane hasło, logowanie z sieci labu | sprzeczne z FR-008a i SC-004 |
| Zmienić `config.ssh.username` na `admin` | jedno konto | `admin` musiałby istnieć w obrazie przed bootstrapem | problem „jajka i kury” |

## Konsekwencje

- **Pozytywne**: `vagrant ssh` działa (US4.6), a z sieci labu konto jest niedostępne (US3.4).
- **Negatywne / ograniczenia**: konto z sudo nadal istnieje; każdy, kto ma dostęp do hosta i
  klucza Vagranta, ma roota na węzłach (akceptowalne — to i tak właściciel hosta).
- **Co byłoby inaczej na produkcji**: takiego konta w ogóle by nie było; dostęp awaryjny przez
  konsolę hiperwizora/BMC.
