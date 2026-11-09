# Notatki z problemów i weryfikacji

Dziennik prowadzony od pierwszego dnia (konstytucja, zasada VI). Z wpisów powstają sekcje
„Typowe problemy” w tutorialach etapów, postmortemy i „Czego się nauczyłem”.

**Format wpisu**:

```text
### RRRR-MM-DD — krótki tytuł
- Objaw:
- Hipotezy:
- Sprawdzenie:
- Przyczyna:
- Naprawa:
```

## Etap 1

### Organizacja pracy (T002)

| Issue | Historyjka |
|---|---|
| #? | US1 — Odtworzenie środowiska od zera |
| #? | US2 — Idempotentna konfiguracja bazowa |
| #? | US3 — Bezpieczny dostęp administracyjny |
| #? | US4 — Firewall z domyślną odmową |
| #? | US5 — Czas, strefa czasowa i aktualizacje |
| #? | US6 — Automatyczna kontrola jakości kodu |
| #? | US7 — Dokumentacja etapu jako tutorial |
| #? | Etap 1: zamknięcie etapu |

Numery uzupełnić po założeniu Issues w GitHubie.

### 2026-11-09 — weryfikacja pozycji [WERYFIKACJA] z research.md (T007)

- **(a) Obraz `bento/debian-13` (R2)**: najnowsza wersja w Vagrant Cloud `202510.26.0`, dostępna
  dla providera `virtualbox` w architekturze `amd64` (także arm64, vmware_desktop, parallels).
  Przypięta w `Vagrantfile` (`box_version`). Obecność dodatków gościa VirtualBoxa — obrazy Bento
  je zawierają; do potwierdzenia przy pierwszym `vagrant up` (`mount | grep vboxsf` na `ops`).
- **(b) ansible-core i ansible-lint (R7)**: na PyPI dostępne gałęzie 2.20 (2.20.11), 2.21
  (2.21.6) i 2.22 (2.22.0) — wszystkie wydane/łatane 2026-11-02 i zgodne z Pythonem 3.13 z
  Debiana 13. Wybrano **ansible-core 2.21.6**: najnowsza łatka stabilnej gałęzi; 2.22.0 to
  wydanie `.0` sprzed tygodnia (pierwsze łatki zwykle naprawiają regresje), a 2.20 zbliża się do
  końca wsparcia. `ansible-lint 26.11.0` wymaga `ansible-core>=2.16.19,!=2.17.*` — zgodny.
  Kolekcje: `ansible.posix 2.2.2` (wymaga ansible ≥ 2.16), `community.general 14.0.0`
  (wymaga ansible ≥ 2.19) — zgodne. Inne narzędzia: `yamllint 1.38.0`, `pre-commit 4.7.0`,
  `pre-commit-hooks v6.0.0`, `actions/checkout v7.0.1`, `actions/setup-python v7.1.0`.
  Decyzja R7 zmieniona względem „docelowo 2.20” — research.md zaktualizowany.
- **(c) Wersje na hoście**: `VBoxManage --version` → `7.2.16r174877` (VirtualBox 7.x — OK).
  Vagrant początkowo niezainstalowany; po instalacji `vagrant --version` → `Vagrant 2.4.9`
  (2.4.x — OK).

### 2026-11-09 — testy akceptacyjne przed implementacją

Kontrakt testów zakłada uruchomienie `playbooks/verify/stage1.yml --tags usN` przed
implementacją każdej historyjki (oczekiwana porażka). Playbooki weryfikacyjne powstały razem z
implementacją, zanim środowisko było dostępne (brak Vagranta na hoście), więc przebiegów „przed”
nie wykonano. Do odnotowania przy pierwszym uruchomieniu: na świeżo postawionych maszynach (po
`vagrant up`, przed `site.yml`) uruchomić `verify/stage1.yml` i zapisać tu, które asercje padły
(oczekiwane: US1.4 — `127.0.1.1`/brak wpisów, US3 — `sshd -T`, US4 — brak `policy drop`,
US5 — strefa czasowa/konfiguracja aktualizacji).

### Pozycje do sprawdzenia przy pierwszym uruchomieniu

- R9: `systemctl status ssh.socket ssh.service` na węźle — handler zakłada `ssh.service`
  (Debian 13 domyślnie nie używa socket activation). Jeśli `ssh.socket` jest aktywny — zmienić
  handler w `roles/common/handlers/main.yml`.
- R8: `include "/etc/nftables.d/*.nft"` przy pustym katalogu — rola od razu tworzy plik
  `/etc/nftables.d/00-common.nft` (sam komentarz), więc wzorzec zawsze ma dopasowanie; sprawdzić
  `nft -c -f /etc/nftables.conf` mimo to.
- R11: czy `apt` z `update_cache` + `cache_valid_time` raportuje `changed` w drugim przebiegu;
  `needrestart -b -k` na Debianie 13 (kod 0, linia `NEEDRESTART-KSTA:`).
- R10: `chronyd -p -f` (walidacja szablonu chrony) — dostępne w chrony ≥ 4.0.
