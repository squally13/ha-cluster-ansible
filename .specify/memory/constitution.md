<!--
Sync Impact Report
==================
Version change: (szablon, brak wersji) → 1.0.0
Bump rationale: pierwsza ratyfikacja konstytucji — wszystkie placeholdery szablonu zastąpione
treścią projektu (MAJOR = 1 dla wersji początkowej).

Modified principles (szablon → projekt):
  - [PRINCIPLE_1_NAME] → I. Wszystko jako kod (zero ręcznych zmian)
  - [PRINCIPLE_2_NAME] → II. Idempotencja i odtwarzalność od zera (NON-NEGOTIABLE)
  - [PRINCIPLE_3_NAME] → III. Konwencje ról Ansible
  - [PRINCIPLE_4_NAME] → IV. Sekrety wyłącznie w Ansible Vault
  - [PRINCIPLE_5_NAME] → V. Decyzje architektoniczne jako ADR
  - (nowa)             → VI. Dokumentacja jako tutorial

Added sections:
  - Git i przepływ pracy (z [SECTION_2_NAME])
  - Definicja ukończenia etapu i zasady pracy (z [SECTION_3_NAME])

Removed sections: brak

Templates requiring updates (nie modyfikowane przez tę komendę — czytają konstytucję w runtime):
  - ⚠ .specify/templates/plan-template.md — sekcja „Constitution Check” powinna weryfikować
    zasady I–VI (w szczególności II: destroy + site.yml + changed=0; V: ADR; VI: tutorial).
  - ⚠ .specify/templates/tasks-template.md — warto dodać zadania końcowe etapu:
    odtworzenie od zera, drugi przebieg changed=0, ADR, dokumentacja tutorialowa.
  - ✅ .specify/templates/spec-template.md — bez zmian wymaganych.

Follow-up TODOs: brak.
-->

# Konstytucja projektu ha-homelab (klaster HA z Ansible)

## Core Principles

### I. Wszystko jako kod (zero ręcznych zmian)

- Każda zmiana konfiguracji węzłów MUSI trafić do repozytorium i być wdrażana przez Ansible.
  Ręczne zmiany na serwerach (SSH + edycja plików, `pcs`, `mysql` „z palca”) są zabronione,
  poza diagnostyką i krokami runbooka opisanymi jako ręczne (np. promowanie repliki MySQL).
- Cały klaster MUSI dać się postawić poleceniami `vagrant up` oraz
  `ansible-playbook playbooks/site.yml`; `site.yml` importuje playbooki warstw.
- Wersje oprogramowania MUSZĄ być przypięte w repo (kolekcje w `requirements.yml` z wersjami,
  tagi obrazów kontenerów — nigdy `latest`).

**Uzasadnienie**: projekt ma udowodnić myślenie automatyzacją; każda ręczna zmiana łamie
powtarzalność i jest niewidoczna w historii.

### II. Idempotencja i odtwarzalność od zera (NON-NEGOTIABLE)

- Drugi przebieg `ansible-playbook playbooks/site.yml` MUSI zakończyć się `changed=0` na
  wszystkich hostach.
- Zadania `ansible.builtin.command`/`shell` MUSZĄ mieć `changed_when`, `creates`/`removes` lub
  warunek oparty na wcześniejszym zadaniu sprawdzającym (np. `pcs resource config vip`,
  `getreplica`). Konfiguracje stanowe (klaster Pacemaker, replikacja MySQL) NIE MOGĄ być
  resetowane przy każdym uruchomieniu.
- Każdy etap kończy się pełnym odtworzeniem od zera:
  `vagrant destroy -f && vagrant up && ansible-playbook playbooks/site.yml` bez błędów,
  a następnie drugim przebiegiem `site.yml` z wynikiem `changed=0`. Wynik obu przebiegów
  (PLAY RECAP) MUSI być odnotowany w opisie pull requesta etapu.

**Uzasadnienie**: idempotencja to pierwsze, na co patrzy doświadczony administrator; test od
zera wykrywa ukryte zależności od ręcznego stanu maszyn.

### III. Konwencje ról Ansible

- **Zmienne z prefiksem roli** (`haproxy_maxconn`, `mysql_server_id`); wartości domyślne w
  `roles/<rola>/defaults/main.yml`, nadpisywane w `group_vars`/`host_vars`.
- **Szablony zamiast `lineinfile`**: całe pliki konfiguracyjne w `templates/*.j2`, każdy z
  nagłówkiem „Zarządzane przez Ansible”.
- **Handlery** do restartów i przeładowań; bezwarunkowy restart w zadaniu jest zabroniony.
- **Walidacja przed przeładowaniem**: szablony konfiguracji usług MUSZĄ używać `validate:`
  (np. `haproxy -c -f %s`, `sshd -t -f %s`) lub równoważnej kontroli (`nginx -t`), żeby zły
  szablon nie położył usługi.
- **Tagi** na rolach (np. `--tags haproxy`), aby można było wdrażać jedną warstwę.
- Struktura repo zgodna z planem: `roles/`, `playbooks/` (w tym `chaos/`),
  `inventories/lab/`, `app/`, `docs/`.
- Kod MUSI przechodzić `yamllint` i `ansible-lint` (lokalnie przez `pre-commit`, w CI przez
  GitHub Actions).

**Uzasadnienie**: spójne konwencje czynią repo czytelnym jak firmowe repo infrastruktury i
chronią usługi przed błędną konfiguracją.

### IV. Sekrety wyłącznie w Ansible Vault

- Wszystkie hasła i tokeny (root MySQL, użytkownik replikacji, użytkownik aplikacji, hasło
  `hacluster`, hasło statystyk HAProxy, token Cloudflare) MUSZĄ znajdować się w
  `inventories/lab/group_vars/all/vault.yml` zaszyfrowanym `ansible-vault`.
- Zmienne jawne odwołują się do sekretów pośrednio, np.
  `mysql_root_password: "{{ vault_mysql_root_password }}"`; prefiks `vault_` oznacza sekret.
- Plik z hasłem do vaulta MUSI być w `.gitignore`; README opisuje, jak go utworzyć.
- Zadania operujące na sekretach SHOULD używać `no_log: true`, aby sekret nie trafił do logów.
- Sekret w postaci jawnej w historii Git wymaga natychmiastowej rotacji.

**Uzasadnienie**: repo jest publiczne (portfolio); wyciek sekretu jest nieodwracalny.

### V. Decyzje architektoniczne jako ADR

- Każda istotna decyzja MUSI być zapisana jako ADR w `docs/adr/` w pliku
  `NNNN-krotki-tytul.md` (numeracja rosnąca, czterocyfrowa).
- Istotna decyzja to m.in.: wybór dystrybucji, narzędzi i wersji; wybór mechanizmu HA
  (Pacemaker vs keepalived); model replikacji (asynchroniczna, GTID); wyłączenie STONITH w
  labie; ręczny failover bazy; sposób publikacji (Cloudflare Tunnel); projekt health checków
  (`/healthz` vs `/livez`/`/readyz`); każde świadome odstępstwo od tej konstytucji.
- ADR zawiera co najmniej: Status (Proponowany/Przyjęty/Zastąpiony przez NNNN), Kontekst,
  Decyzja, Rozważane alternatywy, Konsekwencje (w tym ograniczenia i co byłoby inaczej na
  produkcji).
- ADR-ów się nie edytuje merytorycznie po przyjęciu; zmiana decyzji = nowy ADR, który
  zastępuje poprzedni.
- Sekcja README „Decyzje projektowe” MUSI odwoływać się do odpowiednich ADR.

**Uzasadnienie**: świadome granice projektu i uzasadnione wybory są materiałem na rozmowę
techniczną i chronią przed powtarzaniem tych samych dyskusji.

### VI. Dokumentacja jako tutorial

- Dokumentacja w `docs/` (architektura, opisy etapów, runbooki) MUSI być napisana jako
  tutorial, w którym każdy krok zawiera:
  1. **Co** — jaki jest cel kroku;
  2. **Dlaczego** — uzasadnienie (z odwołaniem do ADR, jeśli dotyczy);
  3. **Komenda** — dokładne polecenie do skopiowania, z hostem, na którym się je wykonuje;
  4. **Weryfikacja** — polecenie sprawdzające wraz z **oczekiwanym wynikiem**
     (np. `Replica_IO_Running: Yes`, `changed=0`, kod HTTP 200);
  5. **Typowe problemy** — objaw, prawdopodobna przyczyna, jak sprawdzić i naprawić.
- Runbooki (`docs/runbooks/`) MUSZĄ być przetestowane ręcznie co najmniej raz przed
  zamknięciem etapu, którego dotyczą.
- Notatki z problemów prowadzone są od pierwszego dnia w `docs/notes.md`; powstają z nich
  sekcja „Typowe problemy”, postmortemy (`docs/postmortems/`) i „Czego się nauczyłem”.
- Dokumentacja jest częścią etapu: etap bez zaktualizowanej dokumentacji nie jest ukończony.

**Uzasadnienie**: osoba klonująca repo ma odtworzyć klaster bez pytania autora; każde
miejsce, w którym utknie, jest błędem dokumentacji.

## Git i przepływ pracy

- Gałąź `main` zawsze działa. Każdy etap powstaje na osobnej gałęzi i trafia do `main`
  przez pull request z opisem (także gdy autor recenzuje sam siebie).
- Małe commity z opisem w formacie `<obszar>: <co zmieniono>`, np.
  `haproxy: add health check on /healthz`.
- Pull requesty linkują do Issues (`Closes #12`); zadania etapów prowadzone są w GitHub
  Project (Kanban). Problem blokujący dłużej niż 2 godziny zapisuje się jako Issue z listą
  tego, co już sprawdzono.
- GitHub Actions uruchamia `yamllint` i `ansible-lint` na każdym pushu; czerwony lint blokuje
  merge do `main`.
- Kamienie milowe oznaczane są tagami (`m1`, `m2`), a zakończenie projektu tagiem `v1.0`.
- Repozytorium jest publiczne od pierwszego tygodnia; preferowane są regularne commity.

## Definicja ukończenia etapu i zasady pracy

Etap jest ukończony dopiero, gdy spełnione są WSZYSTKIE warunki:

1. Spełnione są kryteria ukończenia etapu z planu projektu.
2. Pełne odtworzenie od zera (`vagrant destroy -f && vagrant up &&
   ansible-playbook playbooks/site.yml`) przechodzi bez błędów.
3. Drugi przebieg `site.yml` daje `changed=0` na wszystkich hostach.
4. Lint w GitHub Actions jest zielony.
5. Istotne decyzje etapu mają ADR w `docs/adr/` (zasada V).
6. Dokumentacja etapu i runbooki są w formie tutorialu z weryfikacją i oczekiwanym wynikiem
   (zasada VI), a `docs/notes.md` jest uzupełnione.
7. Pull request etapu zawiera PLAY RECAP z obu przebiegów oraz linki do ADR i Issues.

Zasady dodatkowe:

- Granice projektu są deklarowane jawnie (np. ręczny failover MySQL, STONITH wyłączony w
  labie) — w ADR i README — zamiast udawania pełnej automatyzacji.
- Testy awarii (etap 6) MUSZĄ mieć zmierzone wyniki (liczba nieudanych żądań, czas przerwy)
  wpisane do README; scenariusze 1–5 SHOULD być zautomatyzowane w `playbooks/chaos/`.
- Firewall ma domyślną politykę drop; otwierane są tylko porty z tabeli architektury i tylko
  dla wskazanych źródeł.

## Governance

- Konstytucja ma pierwszeństwo przed innymi praktykami w repozytorium. Specyfikacje, plany i
  zadania Spec Kit MUSZĄ być z nią zgodne; sekcja „Constitution Check” planu weryfikuje
  zasady I–VI.
- Zmiana konstytucji wymaga pull requesta, który aktualizuje ten plik, podnosi wersję i —
  jeśli zmiana jest istotna — dodaje ADR uzasadniający poprawkę.
- Wersjonowanie semantyczne: MAJOR — usunięcie lub redefinicja zasady niezgodna wstecz;
  MINOR — nowa zasada/sekcja lub istotne rozszerzenie; PATCH — doprecyzowania i poprawki
  redakcyjne.
- Każdy pull request etapu jest sprawdzany pod kątem zgodności z Definicją ukończenia.
  Odstępstwo od zasady jest dopuszczalne tylko z ADR opisującym powód, zakres i plan
  usunięcia odstępstwa.
- Bieżące wskazówki operacyjne znajdują się w `Plan_projektu_klaster_HA.md` i `docs/`.

**Version**: 1.0.0 | **Ratified**: 2026-11-08 | **Last Amended**: 2026-11-08
