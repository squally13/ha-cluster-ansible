# Feature Specification: Etap 2 — Baza danych z replikacją source → replica (GTID)

**Feature Branch**: `002-etap2-mysql-replikacja`

**Created**: 2026-11-11

**Status**: Draft

**Input**: User description: "Etap 2" — sekcja 6 `Plan_projektu_klaster_HA.md` („MySQL source →
replica z GTID”). Plan traktowany jako punkt wyjścia: kryteria ukończenia zamienione na
testowalne scenariusze, rozbieżności i ryzyka wypisane poniżej.

## Clarifications

### Session 2026-11-11

- Q: Co dzieje się ze starym źródłem (`db1`) po promowaniu `db2`? → A: `db1` wraca jako nowa
  replika `db2` — runbook zmienia role w inventory i uruchamia `site.yml`; powrót do układu
  wyjściowego to ten sam runbook wykonany w drugą stronę (opcja A, rekomendacja).
- Q: Czy odtworzenie samej repliki, gdy źródło ma już dane, ma działać automatycznie? → A: Tak —
  Ansible zasila pustą replikę danymi ze źródła (sklonowanie instancji) przed uruchomieniem
  replikacji; dowolny węzeł bazy da się odtworzyć jednym przebiegiem `site.yml` (opcja A,
  rekomendacja).

## Kontekst i rozbieżności znalezione w planie

Etap 2 buduje na środowisku z etapu 1 (7 maszyn Debian 13, rola bazowa, firewall z polityką
odmowy, Ansible uruchamiany z `ops`). Przy przekładaniu planu na wymagania wykryto:

- **Regresja testów etapu 1**: test US4.1/US4.2 etapu 1 uruchamia na `db1` tymczasowy nasłuch na
  porcie 3306 i oczekuje, że połączenie z `web1` zostanie porzucone. Po etapie 2 port 3306 na
  `db1` jest zajęty przez bazę i **celowo** otwarty dla `web1` — test etapu 1 przestałby
  przechodzić albo zacząłby testować nieprawdę. Wymóg: test firewalla etapu 1 MUSI nadal
  dowodzić polityki odmowy, ale na porcie, którego żaden etap nie otwiera (FR-021).
- **Debian 13 a oficjalne pakiety bazy**: plan zakłada MySQL 8.4 LTS z repozytorium producenta;
  Debian 13 w swoich repozytoriach dostarcza MariaDB, nie MySQL. Dostępność oficjalnych pakietów
  8.4 dla Debiana 13 (zapowiedziana jako ryzyko w spec etapu 1) MUSI zostać zweryfikowana na
  początku planowania; brak pakietów to decyzja do ADR, nie ciche przejście na MariaDB.
- **Adres nasłuchu**: plan ustawia nasłuch bazy wyłącznie na adresie w sieci labu. Lokalne
  połączenia administracyjne na węźle bazy MUSZĄ działać niezależnie od tego (np. przez gniazdo
  lokalne), inaczej zarządzanie bazą z Ansible zależy od reguł sieciowych.
- **Sekrety**: etap 2 jest pierwszym etapem z sekretami (hasło administratora bazy, hasło
  replikacji, hasło użytkownika aplikacji). Magazyn sekretów (zasada IV) nie istnieje jeszcze w
  repozytorium — powstaje w tym etapie, razem z instrukcją utworzenia hasła do niego.
- **„Backup przed zmianami”**: tabela mapowania wymagań planu przypisuje bazie „backup przed
  zmianami”, ale kroki etapu 2 o nim nie wspominają, a sekcja „Poza zakresem” wyłącza backupy jako
  osobny projekt — patrz FR-019.
- **Promowanie repliki a „wszystko jako kod”**: runbook promowania jest dozwolonym wyjątkiem od
  zasady I (konstytucja wymienia go z nazwy), ale po ręcznym promowaniu kolejny przebieg
  głównego playbooka nie może po cichu przywrócić starego układu ról (`db1` source, `db2`
  replika) i zepsuć danych. Wymóg w FR-017/FR-018.
- **Odbudowa samej repliki**: kryterium planu („replikacja działa po `vagrant destroy` i
  ponownym `site.yml`”) obejmuje odtworzenie całego labu (obie bazy puste). Odtworzenie tylko
  `db2`, gdy `db1` ma już dane, to inny przypadek — patrz FR-012.
- **Weryfikacja z węzłów WWW**: w etapie 2 nie ma jeszcze aplikacji, a dostęp do bazy dla
  użytkownika aplikacji ma być możliwy tylko z `web1`/`web2`. Test MUSI wykonać prawdziwe
  logowanie z tych węzłów (nie tylko test portu).

## User Scenarios & Testing *(mandatory)*

Aktorzy: **Administrator** (autor projektu, uruchamia playbooki z `ops`), **Recenzent**
(osoba klonująca repo), **Aplikacja** (w etapie 3 — konto aplikacji łączące się z `web1`/`web2`).

### User Story 1 - Baza danych na obu węzłach `db` z bezpieczną konfiguracją (Priority: P1)

Po uruchomieniu głównego playbooka na `db1` i `db2` działa serwer bazy w przypiętej wersji, z
konfiguracją w całości z repozytorium, bez kont anonimowych i testowej bazy, a konto
administracyjne bazy nie jest dostępne zdalnie.

**Why this priority**: bez działającej bazy nie ma replikacji ani aplikacji (etap 3).

**Independent Test**: po przebiegu playbooka sprawdzić na obu węzłach wersję, stan usługi,
listę kont i baz.

**Acceptance Scenarios**:

1. **Given** środowisko po etapie 1, **When** Administrator uruchamia główny playbook,
   **Then** przebieg kończy się `failed=0`, a na `db1` i `db2` usługa bazy jest aktywna,
   włączona przy starcie i raportuje wersję przypiętą w repozytorium (8.4.x).
2. **Given** skonfigurowane węzły `db`, **When** Administrator wylistowuje konta i bazy,
   **Then** nie ma kont anonimowych ani testowej bazy, a konto administracyjne bazy istnieje
   wyłącznie dla połączeń lokalnych.
3. **Given** skonfigurowane węzły `db`, **When** Administrator sprawdza identyfikatory serwerów,
   **Then** każdy węzeł ma inny, niezerowy identyfikator zdefiniowany w repozytorium, a tryb
   GTID i dziennik binarny są włączone na obu.
4. **Given** szablon konfiguracji bazy z błędem, **When** Administrator uruchamia playbook,
   **Then** przebieg kończy się czytelnym błędem, a działająca usługa nie zostaje zrestartowana
   z błędną konfiguracją (dalej przyjmuje połączenia).
5. **Given** węzły `lb`, `web`, `ops`, **When** Administrator sprawdza zainstalowane usługi,
   **Then** serwer bazy działa wyłącznie na węzłach grupy `db`.

---

### User Story 2 - Replikacja `db1` → `db2` konfigurowana automatycznie (Priority: P1)

`db1` przyjmuje zapisy, `db2` jest repliką nadążającą za `db1`; replikację w całości ustawia
Ansible (bez ręcznego wydawania poleceń na bazie).

**Why this priority**: sedno etapu i kryterium ukończenia z planu.

**Independent Test**: na świeżym środowisku: przebieg playbooka, potem zapis na `db1` i odczyt
na `db2`.

**Acceptance Scenarios**:

1. **Given** świeżo odtworzone środowisko (obie bazy puste), **When** Administrator uruchamia
   główny playbook, **Then** na `db2` oba wątki replikacji działają, a opóźnienie wobec `db1`
   wynosi 0 s.
2. **Given** działająca replikacja, **When** Administrator zapisuje wiersz testowy na `db1`,
   **Then** ten wiersz jest widoczny na `db2` w ciągu 5 s.
3. **Given** działająca replikacja, **When** Administrator sprawdza konfigurację źródła na `db2`,
   **Then** replika łączy się z `db1` po adresie z sieci labu, używa automatycznego
   pozycjonowania GTID i dedykowanego konta replikacji.
4. **Given** konto replikacji na `db1`, **When** ktoś próbuje użyć go z innego węzła niż `db2`
   (np. z `web1`), **Then** logowanie jest odrzucone.
5. **Given** działająca replikacja, **When** Administrator restartuje usługę bazy na `db2`
   (lub cały węzeł), **Then** po starcie replikacja wznawia się sama i nadrabia zapisy wykonane
   w tym czasie na `db1`.

---

### User Story 3 - Idempotencja: ponowny przebieg nie rusza replikacji (Priority: P1)

Drugi przebieg głównego playbooka na działającym klastrze nie zmienia niczego — w szczególności
nie zatrzymuje, nie resetuje i nie konfiguruje ponownie replikacji ani nie zmienia haseł.

**Why this priority**: zasada II konstytucji (NON-NEGOTIABLE) i kryterium planu.

**Independent Test**: dwa kolejne przebiegi, między nimi zapisy na `db1`.

**Acceptance Scenarios**:

1. **Given** środowisko tuż po pierwszym przebiegu, **When** Administrator uruchamia playbook
   ponownie, **Then** podsumowanie pokazuje `changed=0`, `failed=0` na 7/7 hostach.
2. **Given** działająca replikacja i zapisy na `db1` między przebiegami, **When** Administrator
   uruchamia playbook, **Then** licznik wykonanych transakcji na `db2` nie cofa się, replikacja
   nie jest restartowana (czas działania wątków replikacji się nie zeruje), a dane testowe
   pozostają.
3. **Given** środowisko po konfiguracji, **When** Administrator uruchamia playbook w trybie
   sprawdzania z podglądem różnic, **Then** nie są raportowane żadne zmiany.

---

### User Story 4 - Replika tylko do odczytu (Priority: P1)

Każda próba zapisu na `db2` — także przez konto z szerokimi uprawnieniami — kończy się błędem,
żeby replika nie rozjechała się ze źródłem.

**Why this priority**: zapis na replice to najczęstsza przyczyna zatrzymania replikacji
(plan, sekcja 13: błąd 1062).

**Independent Test**: próba zapisu na `db2` kontem aplikacji i kontem administracyjnym.

**Acceptance Scenarios**:

1. **Given** działająca replikacja, **When** konto aplikacji próbuje zapisać na `db2`,
   **Then** zapis jest odrzucony z błędem trybu tylko do odczytu.
2. **Given** działająca replikacja, **When** konto administracyjne bazy próbuje zapisać na `db2`,
   **Then** zapis także jest odrzucony.
3. **Given** restart `db2`, **When** usługa wstaje, **Then** tryb tylko do odczytu obowiązuje od
   startu (nie ma okna, w którym zapis jest możliwy).

---

### User Story 5 - Baza i konto aplikacji z dostępem tylko z węzłów WWW (Priority: P2)

Istnieje baza `app` i konto `app`, które może się zalogować wyłącznie z `web1` i `web2`;
port bazy jest otwarty w firewallu tylko dla węzłów, które go potrzebują.

**Why this priority**: przygotowanie pod etap 3; zasada „porty tylko dla wskazanych źródeł”.

**Independent Test**: logowanie kontem aplikacji z różnych węzłów i testy portu.

**Acceptance Scenarios**:

1. **Given** skonfigurowane węzły, **When** konto `app` loguje się do `db1` z `web1` i z `web2`,
   **Then** logowanie się udaje i konto ma pełne uprawnienia do bazy `app`, a do innych baz —
   żadnych.
2. **Given** skonfigurowane węzły, **When** konto `app` próbuje się zalogować do `db1` z `db2`
   (jedyny węzeł spoza grupy `web`, który ma sieciowy dostęp do portu bazy), **Then** logowanie
   jest odrzucone przez bazę — ograniczenie działa niezależnie od firewalla.
3. **Given** skonfigurowane węzły, **When** z `lb1` lub `ops` następuje połączenie z
   `db1:3306` (limit 3 s), **Then** połączenie nie zostaje nawiązane (timeout — porzucone przez
   firewall); **When** z `web1`, `web2` lub `db2`, **Then** połączenie TCP zostaje nawiązane.
4. **Given** te same reguły na `db2`, **When** łączą się `web1`, `web2`, `db1`, **Then** połączenie
   TCP zostaje nawiązane, a z pozostałych węzłów — timeout.
5. **Given** zmiana listy węzłów WWW w inventory (np. dodanie `web3`), **When** Administrator
   uruchamia playbook, **Then** reguły firewalla i dozwolone źródła konta `app` aktualizują się
   bez edycji ról.

---

### User Story 6 - Ręczne promowanie repliki według runbooka (Priority: P2)

Gdy `db1` jest niedostępny, Administrator według runbooka promuje `db2` do roli źródła;
po promowaniu `db2` przyjmuje zapisy, a kolejny przebieg playbooka nie cofa promowania.

**Why this priority**: kryterium ukończenia z planu („runbook przetestowany ręcznie choć raz”)
i świadomie zadeklarowana granica projektu (brak automatycznego przełączenia bazy).

**Independent Test**: zatrzymać bazę na `db1`, wykonać runbook krok po kroku, sprawdzić zapis
na `db2`, uruchomić playbook.

**Acceptance Scenarios**:

1. **Given** działająca replikacja i zatrzymana baza na `db1`, **When** Administrator wykonuje
   runbook promowania, **Then** `db2` przyjmuje zapisy kontem aplikacji, a żadna transakcja
   potwierdzona na `db1` przed awarią i zreplikowana na `db2` nie zostaje utracona.
2. **Given** wykonany runbook (łącznie z jego krokiem aktualizacji repozytorium),
   **When** Administrator uruchamia główny playbook, **Then** przebieg nie przywraca `db2` do
   roli repliki ani nie włącza na nim trybu tylko do odczytu; drugi przebieg daje `changed=0`.
3. **Given** promowany `db2` i przywrócony do działania `db1`, **When** Administrator wykonuje
   część runbooka dotyczącą starego źródła, **Then** po zmianie ról w repozytorium i przebiegu głównego playbooka `db1` jest repliką
   `db2`: oba wątki replikacji działają, `db1` ma wszystkie transakcje `db2` (także te zapisane
   po promowaniu), jest w trybie tylko do odczytu, a drugi przebieg daje `changed=0`. Transakcje,
   które `db1` miał, a które nie zdążyły trafić na `db2` przed awarią, są wykrywane i opisane w
   runbooku (rozbieżny `db1` jest zasilany od nowa ze `db2` zamiast dołączać z konfliktem).
4. **Given** układ po scenariuszu 3, **When** Administrator wykonuje ten sam runbook w drugą
   stronę (promowanie `db1`), **Then** wraca układ wyjściowy (`db1` źródło, `db2` replika)
   bez utraty danych i bez dodatkowych kroków spoza runbooka.
5. **Given** runbook, **When** Recenzent go czyta, **Then** każdy krok ma: co, dlaczego,
   komendę z hostem, weryfikację z oczekiwanym wynikiem i typowe problemy, a na początku jest
   kryterium decyzji „kiedy promować” (i kiedy nie — np. `db1` tylko chwilowo niedostępny).

---

### User Story 7 - Dokumentacja etapu jako tutorial i decyzje w ADR (Priority: P3)

Recenzent odtwarza etap 2 na podstawie dokumentacji; decyzje etapu są opisane w ADR, a README
mówi wprost, że przełączenie bazy jest ręczne.

**Why this priority**: zasady V i VI konstytucji.

**Independent Test**: przegląd dokumentacji wg kryteriów zasady VI; przejście tutorialu na
świeżym środowisku po etapie 1.

**Acceptance Scenarios**:

1. **Given** dokumentacja etapu 2, **When** Recenzent ją czyta, **Then** każdy krok ma co,
   dlaczego, komendę, weryfikację z oczekiwanym wynikiem (np. `Replica_IO_Running: Yes`) i typowe
   problemy (m.in. replikacja zatrzymana błędem 1236/1062).
2. **Given** zamykany etap, **When** sprawdzane są ADR, **Then** istnieją ADR co najmniej dla:
   źródła i wersji pakietów bazy na Debianie 13, modelu replikacji (asynchroniczna, GTID),
   ręcznego przełączenia bazy, magazynu sekretów.
3. **Given** README, **When** Recenzent czyta sekcję decyzji, **Then** znajduje jawną deklarację
   „failover bazy jest ręczny” z odnośnikiem do runbooka i ADR.

---

### Edge Cases

- **Pierwszy start bazy a konto administratora**: instalacja pakietu nie może zostawić konta
  administracyjnego z pustym hasłem dostępnym po sieci; konto uwierzytelnia się gniazdem
  lokalnym (FR-004), więc kolejne przebiegi nie mają hasła do porównywania (częsty powód
  `changed>0`).
- **Brak hasła do magazynu sekretów na `ops`**: przebieg MUSI zakończyć się od razu czytelnym
  błędem, zanim cokolwiek zostanie zmienione na węzłach.
- **Sekrety w logach**: zadania operujące na hasłach nie mogą wypisywać ich w wyjściu przebiegu
  ani przy błędzie.
- **Replika startuje przed źródłem** (np. `vagrant up` w innej kolejności, restart `db1`):
  replikacja ponawia połączenie i działa po dostępności `db1` bez ręcznej ingerencji.
- **Odtworzenie tylko `db2` przy `db1` z danymi**: replika zasilana automatycznie (FR-012);
  test: `vagrant destroy -f db2 && vagrant up db2`, `site.yml` → dane i replikacja jak przed
  odtworzeniem.
- **Zasilanie repliki trwa, a źródło przyjmuje zapisy**: zapisy wykonane w trakcie kopiowania
  MUSZĄ trafić na replikę po uruchomieniu replikacji (brak luki w danych).
- **Stare źródło z niezreplikowanymi transakcjami** po promowaniu: nie może dołączyć jako
  replika z rozbieżnymi danymi — runbook każe je zasilić od nowa (US6.3).
- **Zapis na replice mimo wszystko** (np. błąd operatora przed włączeniem trybu tylko do
  odczytu): replikacja staje z błędem; dokumentacja opisuje objaw (`Last_SQL_Error`, błąd 1062)
  i naprawę w „Typowych problemach”.
- **Usunięte dzienniki binarne na źródle** (błąd 1236): opisane w „Typowych problemach”;
  konfiguracja retencji dzienników musi być jawna w repozytorium.
- **Pamięć węzła `db`** (1,5 GB): domyślne ustawienia bazy mogą zająć większość pamięci;
  konfiguracja MUSI być dobrana tak, by węzeł nie wpadał w OOM przy pracy labu.
- **Ponowny przebieg po promowaniu bez aktualizacji repozytorium**: Administrator zapomniał
  kroku runbooka — przebieg NIE MOŻE zdegradować `db2` do repliki; ma zatrzymać się z
  komunikatem o niezgodności stanu z repozytorium (FR-018).
- **Restart całego labu** (`vagrant halt` / `vagrant up`): replikacja wraca sama (US2.5).

## Requirements *(mandatory)*

### Functional Requirements

**Instalacja i konfiguracja bazy**

- **FR-001**: Serwer bazy MySQL w wersji 8.4 LTS (wersja przypięta w repozytorium) MUSI być
  instalowany wyłącznie na węzłach grupy `db`, z oficjalnego źródła pakietów zweryfikowanego
  dla Debiana 13; źródło i jego klucz podpisu MUSZĄ być zdefiniowane w repozytorium.
- **FR-002**: Konfiguracja serwera MUSI być generowana w całości z szablonu z nagłówkiem
  „Zarządzane przez Ansible”, walidowana przed restartem, a restart następuje tylko po zmianie
  (handler).
- **FR-003**: Każdy węzeł `db` MUSI mieć unikalny, niezerowy identyfikator serwera zdefiniowany
  w zmiennych hosta; GTID i dziennik binarny w formacie wierszowym są włączone na obu węzłach
  (każdy może zostać źródłem).
- **FR-004**: Konfiguracja MUSI wykonywać idempotentnie odpowiednik „secure installation”:
  brak kont anonimowych, brak testowej bazy, konto administracyjne dostępne tylko lokalnie i
  uwierzytelniane tożsamością systemowego administratora węzła (gniazdo lokalne), bez hasła
  (doprecyzowane w planie — research R3: brak sekretu do przechowywania i wycieku).
- **FR-005**: Serwer MUSI nasłuchiwać na adresie węzła w sieci labu; Ansible zarządza bazą przez
  połączenie lokalne na węźle, niezależne od reguł sieciowych.
- **FR-006**: Ustawienia pamięci serwera MUSZĄ być dopasowane do pamięci węzła `db` z inventory
  i jawnie zdefiniowane (z możliwością nadpisania).
- **FR-007**: Retencja dzienników binarnych MUSI być jawnie zdefiniowana w repozytorium.

**Replikacja**

- **FR-008**: Rola węzła bazy (`source`/`replica`) MUSI wynikać z repozytorium (zmienne
  inventory), a nie z kolejności hostów.
- **FR-009**: Na źródle MUSI istnieć dedykowane konto replikacji z wyłącznie uprawnieniami
  replikacji, dostępne tylko z adresów węzłów grupy `db` (wyliczanych z inventory) — każdy z
  nich może po promowaniu zostać repliką (doprecyzowane w planie — research R5).
- **FR-010**: Na replice konfiguracja MUSI ustawiać źródło replikacji (adres `db1` w sieci labu,
  konto replikacji, automatyczne pozycjonowanie GTID) i uruchamiać replikację **tylko wtedy, gdy
  replikacja nie jest jeszcze skonfigurowana**; działająca replikacja nie jest zatrzymywana,
  resetowana ani konfigurowana ponownie.
- **FR-011**: Replika MUSI mieć włączony tryb tylko do odczytu obejmujący także konta
  uprzywilejowane, obowiązujący od startu usługi.
- **FR-012**: Konfiguracja MUSI zestawiać replikację zarówno na pustych bazach (odtworzenie
  całego labu), jak i wtedy, gdy replika jest pusta (nowa lub odtworzona maszyna), a źródło ma
  już dane: przed uruchomieniem replikacji replika jest automatycznie zasilana pełną kopią
  danych ze źródła, bez ręcznych kroków. Zasilenie wykonuje się **wyłącznie** na replice bez
  skonfigurowanej replikacji i bez danych użytkownika — nigdy na węźle, który ma własne dane
  (ochrona przed nadpisaniem; w takim przypadku przebieg zatrzymuje się z komunikatem).
- **FR-013**: Jeśli replikacja jest skonfigurowana, ale zatrzymana błędem, przebieg MUSI to
  zgłosić czytelnym błędem z treścią ostatniego błędu replikacji — nie może jej „naprawiać”
  resetem.

**Konto i baza aplikacji**

- **FR-014**: Na źródle MUSI istnieć baza `app` i konto `app` z pełnymi uprawnieniami wyłącznie
  do tej bazy, dostępne tylko z adresów węzłów grupy `web` (wyliczanych z inventory); obiekty
  te trafiają na replikę przez replikację, nie przez osobną konfigurację.

**Sekrety**

- **FR-015**: Wszystkie hasła etapu (replikacja, zasilanie repliki, aplikacja) MUSZĄ być w
  zaszyfrowanym magazynie sekretów w repozytorium; zmienne jawne odwołują się do nich pośrednio.
  Plik z hasłem do magazynu jest poza Gitem, a dokumentacja opisuje, jak go utworzyć na `ops`.
  Zadania operujące na hasłach nie wypisują ich w logach.

**Firewall**

- **FR-016**: Port 3306 MUSI być otwarty na `db1` dla `web1`, `web2`, `db2`, a na `db2` dla
  `web1`, `web2`, `db1` — źródła wyliczane z inventory, przez mechanizm fragmentów reguł z etapu
  1 (bez edycji roli bazowej); z pozostałych węzłów ruch jest porzucany.

**Przełączenie bazy (ręczne)**

- **FR-017**: Repozytorium MUSI zawierać runbook `docs/runbooks/mysql-promote-replica.md`:
  kryterium decyzji, promowanie `db2`, weryfikacja, aktualizacja repozytorium tak, aby
  odzwierciedlało nowy układ ról, przyłączenie starego źródła jako nowej repliki (US6.3) oraz
  powrót do układu wyjściowego tym samym runbookiem w drugą stronę (US6.4).
  Runbook MUSI zostać wykonany ręcznie co najmniej raz przed zamknięciem etapu, a wynik
  zapisany w `docs/notes.md`.
- **FR-018**: Przebieg głównego playbooka MUSI wykrywać niezgodność między rolą węzła w
  repozytorium a stanem bazy (np. repozytorium mówi „replika”, a węzeł przyjmuje zapisy i nie
  replikuje) i w takim przypadku zatrzymać się z komunikatem, zamiast zmieniać rolę węzła.
- **FR-019**: Runbook MUSI przed promowaniem wymagać zrzutu logicznego danych z węzła, który
  zostanie promowany, i wskazać, gdzie zrzut jest zapisywany. Regularne backupy z rotacją i
  testem odtworzenia są poza zakresem projektu (plan, „Poza zakresem”).

**Testy i regresja**

- **FR-020**: Repozytorium MUSI zawierać playbook weryfikacyjny etapu 2 sprawdzający scenariusze
  US1–US5 automatycznie (w tym zapis na `db1` → odczyt na `db2`, odrzucony zapis na `db2`,
  logowanie konta `app` z `web1`/`web2` i odrzucenie z innego węzła), z danymi testowymi, które
  nie zostają w bazie `app` po teście.
- **FR-021**: Test firewalla etapu 1 MUSI zostać przeniesiony na port, którego nie otwiera żaden
  etap (z adnotacją w dokumentacji etapu 1); weryfikacja etapu 1 i etapu 2 MUSI przechodzić
  razem na środowisku po etapie 2.

**Proces (konstytucja)**

- **FR-022**: Etap kończy się pełnym odtworzeniem od zera (3 próby z rzędu, jak w etapie 1):
  pierwszy przebieg `failed=0 unreachable=0`, drugi `changed=0` na 7/7 hostach, weryfikacja
  etapów 1 i 2 zielona; PLAY RECAP obu przebiegów w opisie pull requesta.
- **FR-023**: Decyzje etapu MUSZĄ mieć ADR (US7.2); tutorial `docs/stages/02-*.md` w formacie
  zasady VI; README z deklaracją ręcznego failoveru bazy; `docs/notes.md` uzupełnione.

### Key Entities

- **Węzeł bazy**: host grupy `db`; atrybuty: identyfikator serwera, rola (`source`/`replica`),
  adres w sieci labu, limit pamięci.
- **Konto administracyjne bazy**: tylko lokalne; uwierzytelnianie gniazdem, bez hasła.
- **Konto replikacji**: tylko uprawnienia replikacji; dozwolone źródła = adresy węzłów `db`.
- **Konto aplikacji `app`**: pełne uprawnienia do bazy `app`; dozwolone źródła = adresy węzłów
  `web`.
- **Baza `app`**: tworzona na źródle, replikowana; schemat dostarcza etap 3.
- **Magazyn sekretów**: zaszyfrowany plik w repozytorium + plik z hasłem poza Gitem.
- **Runbook promowania**: dokument operacyjny z krokami ręcznymi i krokiem aktualizacji
  repozytorium.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Pełne odtworzenie labu od zera kończy się działającą replikacją w 3 kolejnych
  próbach (oba wątki replikacji działają, opóźnienie 0 s), bez żadnego ręcznego kroku na bazie.
- **SC-002**: 7/7 hostów raportuje `changed=0` i `failed=0` w drugim przebiegu po każdym
  odtworzeniu; licznik transakcji wykonanych na replice nie cofa się między przebiegami.
- **SC-003**: Wiersz zapisany na `db1` jest widoczny na `db2` w ≤ 5 s (pomiar w teście).
- **SC-004**: 100% prób zapisu na `db2` (konto aplikacji i administracyjne) kończy się błędem.
- **SC-005**: 0 udanych połączeń z portem bazy z węzłów spoza listy dozwolonych i 0 udanych
  logowań konta `app` spoza węzłów `web`.
- **SC-006**: Czas od `vagrant up` do końca pierwszego przebiegu konfiguracji ≤ 30 min (jak w
  etapie 1; zmierzone i zapisane).
- **SC-007**: Runbook promowania wykonany ręcznie co najmniej raz; po nim `db2` przyjmuje zapisy
  w ≤ 10 min od rozpoczęcia runbooka, 0 utraconych transakcji zreplikowanych przed awarią.
- **SC-008**: 0 haseł w postaci jawnej w historii Git i w wyjściu przebiegów (sprawdzenie
  historii i logu przebiegu).
- **SC-009**: Weryfikacja etapów 1 i 2 przechodzi razem na środowisku po etapie 2 (0 regresji).
- **SC-010**: Odtworzenie samej repliki przy źródle z danymi (`vagrant destroy` jednego węzła
  `db` + przebieg konfiguracji) kończy się działającą replikacją z kompletem danych, bez żadnego
  ręcznego kroku na bazie.
- **SC-011**: Pełny cykl przełączenia (promowanie `db2`, przyłączenie `db1` jako repliki, powrót
  runbookiem w drugą stronę) wykonany co najmniej raz z 0 utraconymi transakcjami
  zreplikowanymi przed awarią.

## Assumptions

- Środowisko, rola bazowa, mechanizm fragmentów firewalla i proces (lint, CI, ochrona `main`,
  GitHub Project) pochodzą z etapu 1 i nie są zmieniane poza FR-021.
- Replikacja jest asynchroniczna (jak w planie); replikacja półsynchroniczna i grupowa są poza
  zakresem — możliwa utrata ostatnich niezreplikowanych transakcji przy awarii źródła jest
  deklarowanym ograniczeniem (ADR).
- Automatyczne przełączenie bazy jest poza zakresem (plan, sekcja 6; rozszerzenie w sekcji 13).
- Aplikacja i schemat bazy `app` powstają w etapie 3; w etapie 2 baza `app` jest pusta poza
  danymi testowymi usuwanymi po teście.
- Szyfrowanie ruchu replikacji i połączeń aplikacji (TLS) w sieci labu jest poza zakresem
  etapu 2; ograniczenie odnotowane w ADR modelu replikacji.
- Monitoring opóźnienia replikacji jest poza zakresem (plan: rozszerzenie z Nagiosem).
- Pamięć węzłów `db` pozostaje 1,5 GB (inventory z etapu 1).
