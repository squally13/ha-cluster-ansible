# Feature Specification: Etap 1 — Fundament (środowisko 7 maszyn i bezpieczny stan bazowy)

**Feature Branch**: `001-etap1-fundament`

**Created**: 2026-11-08

**Status**: Draft

**Input**: User description: "Etap 1 \"Fundament\" z Plan_projektu_klaster_HA.md (sekcja 5). Traktuj plan jako punkt wyjścia, nie jako ostateczną prawdę: kryteria ukończenia z planu zamień na testowalne scenariusze akceptacyjne, a wszystko, co niejasne lub ryzykowne, oznacz do wyjaśnienia."

## Clarifications

### Session 2026-11-08

- Q: Na jakim hiperwizorze i skąd uruchamiane są maszyny (Windows/WSL2)? → A: Vagrant
  uruchamiany na Windowsie z providerem VirtualBox (opcja B). WSL2 nie bierze udziału w
  tworzeniu maszyn.
- Q: Jaki system operacyjny na wszystkich węzłach? → A: Debian 13 (trixie) (opcja A).
- Q: Skąd uruchamiany jest Ansible i skąd firewall dopuszcza SSH? → A: Ansible uruchamiany z
  `ops`; SSH na pozostałe węzły dopuszczony wyłącznie z `ops`, na `ops` — z hosta (opcja A).
- Q: W jaki sposób kod repozytorium trafia na `ops`? → A: Folder współdzielony Vagranta —
  katalog repo z hosta podmontowany na `ops` (opcja A).
- Q: Czy automatyczne poprawki bezpieczeństwa mogą same restartować węzły? → A: Nigdy
  automatycznie; węzeł sygnalizuje potrzebę restartu, restart wykonuje Administrator (opcja A).
- Q: Skąd `ops` bierze klucz SSH do pierwszej konfiguracji węzłów? → A: Dedykowana para kluczy
  labu generowana automatycznie przy pierwszym tworzeniu środowiska, poza Gitem; publiczny na
  wszystkie węzły, prywatny kopiowany na `ops` z poprawnymi uprawnieniami (opcja A).
- Q: Co dzieje się z domyślnym kontem `vagrant` z obrazu? → A: Konto zostaje, hasło
  zablokowane, SSH tylko kluczem i tylko przez kanał zarządzania Vagranta (opcja A,
  rekomendacja).
- Q: Z jakiego adresu hosta `ops` przyjmuje SSH w sieci labu? → A: Wyłącznie z adresu hosta w
  sieci host-only 192.168.56.1 (plus kanał zarządzania Vagranta) (rekomendacja przyjęta
  zbiorczo przez użytkownika).

## Kontekst i rozbieżności znalezione w planie

Plan (sekcja 5) jest punktem wyjścia. Przy przekładaniu go na wymagania wykryto:

- **Sprzeczność w firewallu**: krok 4 mówi o otwarciu „portów z tabeli w sekcji 2”, a kryterium
  ukończenia wymaga, by `web1` NIE łączył się z portem 3306 na `db1` („firewall jeszcze go nie
  otwiera”). Przyjęto: w etapie 1 otwierany jest wyłącznie dostęp administracyjny (SSH); porty
  usług otwierają role etapów, które te usługi wprowadzają (patrz Założenia).
- **Kryterium „nie da się połączyć z 3306” jest niejednoznaczne**: w etapie 1 na `db1` nie działa
  żadna usługa na porcie 3306, więc połączenie i tak się nie uda — test nie odróżniłby działającego
  firewalla od braku usługi. Scenariusz akceptacyjny wymaga więc odróżnienia odrzucenia przez
  firewall (brak odpowiedzi / timeout) od „connection refused” przy uruchomionym testowym nasłuchu.
- **Środowisko uruchomieniowe**: repozytorium jest rozwijane w WSL2 bez wirtualizacji
  zagnieżdżonej (brak `/dev/kvm`), z ok. 7 GB RAM dostępnymi dla WSL. Klaster potrzebuje ok. 7 GB
  dla samych maszyn. Rozstrzygnięte (Q1): Vagrant + VirtualBox uruchamiane na Windowsie, więc
  pamięć maszyn pochodzi z hosta Windows, nie z WSL. Ryzyko: Docker Desktop korzysta z Hyper-V,
  przy którym VirtualBox działa w trybie wolniejszym i bywa niestabilny (patrz Edge Cases).
- **Wersja systemu**: plan wskazuje „Debian 12 albo Rocky Linux 9”. Na dzień 2026-11-08 Debian 12
  jest już wydaniem oldstable (wsparcie LTS), a stabilnym jest Debian 13. Rozstrzygnięte (Q2):
  Debian 13. Ryzyko przeniesione do kolejnych etapów: dostępność oficjalnych pakietów MySQL 8.4
  i HAProxy 2.8 dla Debiana 13 trzeba zweryfikować przed etapami 2 i 4.
- **Węzeł sterujący a firewall**: tabela portów dopuszcza SSH na węzłach tylko z `ops`, a plan
  jednocześnie pozwala pominąć `ops` i uruchamiać Ansible z hosta — te warianty wykluczają się
  przy polityce „drop”. Rozstrzygnięte (Q3): Ansible działa na `ops`, a SSH na pozostałe węzły
  jest dopuszczony wyłącznie z `ops` — wariant bez `ops` nie jest wspierany.
- **Aktualizacja pakietów a `changed=0`**: pełna aktualizacja wszystkich pakietów przy każdym
  przebiegu może zgłaszać zmiany, gdy między przebiegami pojawią się nowe poprawki, i sprawia,
  że dwa odtworzenia od zera mogą dać różne wersje pakietów (ryzyko dla zasady II konstytucji).

## User Scenarios & Testing *(mandatory)*

Aktorzy: **Administrator** (autor projektu), **Recenzent** (rekruter/inżynier klonujący repo).

### User Story 1 - Odtworzenie środowiska od zera jednym zestawem poleceń (Priority: P1)

Administrator (lub Recenzent na własnym komputerze) klonuje repozytorium i za pomocą
udokumentowanych poleceń tworzy wszystkie maszyny labu z ustalonymi nazwami, adresami i pamięcią,
a następnie konfiguruje je jednym uruchomieniem głównego playbooka.

**Why this priority**: bez powtarzalnego środowiska żaden kolejny etap nie istnieje; to też pierwsza
rzecz, którą sprawdzi Recenzent.

**Independent Test**: na czystym hoście wykonać zniszczenie środowiska, utworzenie maszyn i
przebieg konfiguracji; sprawdzić, że wszystkie maszyny odpowiadają na test łączności.

**Acceptance Scenarios**:

1. **Given** brak jakichkolwiek maszyn labu, **When** Administrator wykonuje udokumentowaną
   sekwencję „zniszcz → utwórz → skonfiguruj”, **Then** sekwencja kończy się bez błędów, a
   podsumowanie przebiegu pokazuje `failed=0` i `unreachable=0` dla każdego hosta.
2. **Given** utworzone maszyny, **When** Administrator uruchamia test łączności dla wszystkich
   hostów z inventory, **Then** każdy z 7 hostów (`ops`, `lb1`, `lb2`, `web1`, `web2`, `db1`, `db2`)
   odpowiada sukcesem.
3. **Given** utworzone maszyny, **When** Administrator sprawdza adres w sieci labu na każdej
   maszynie, **Then** adresy są zgodne z tabelą architektury (np. `db1` = 192.168.56.31) i każdy
   host jest osiągany przez inventory właśnie pod tym adresem, a nie przez adres NAT.
4. **Given** środowisko po konfiguracji, **When** Administrator rozwiązuje nazwę dowolnego innego
   węzła z dowolnego węzła (np. `lb1` z `lb2`), **Then** nazwa rozwiązuje się na adres z sieci
   labu, a własna nazwa hosta nie rozwiązuje się na adres pętli zwrotnej `127.0.1.1`.

---

### User Story 2 - Idempotentna konfiguracja bazowa (Priority: P1)

Administrator uruchamia konfigurację drugi raz na już skonfigurowanym środowisku i nie powoduje
ona żadnych zmian.

**Why this priority**: zasada II konstytucji (NON-NEGOTIABLE); bez niej etap nie może być uznany.

**Independent Test**: dwa kolejne przebiegi głównego playbooka; drugi raportuje zero zmian.

**Acceptance Scenarios**:

1. **Given** środowisko tuż po pierwszym przebiegu, **When** Administrator uruchamia główny
   playbook ponownie, **Then** podsumowanie pokazuje `changed=0`, `failed=0` dla wszystkich hostów.
2. **Given** środowisko po konfiguracji, **When** Administrator uruchamia playbook w trybie
   sprawdzania z podglądem różnic, **Then** nie są raportowane żadne różnice w zarządzanych plikach.
3. **Given** Administrator ręcznie zmienił zarządzany plik konfiguracyjny (np. konfigurację SSH),
   **When** uruchamia playbook, **Then** plik wraca do stanu z repozytorium, przebieg raportuje
   zmianę na tym hoście, a kolejny przebieg znów daje `changed=0`.

---

### User Story 3 - Bezpieczny dostęp administracyjny (Priority: P1)

Każda maszyna ma konto administracyjne `admin` z logowaniem wyłącznie kluczem i uprawnieniami
sudo; logowanie hasłem i bezpośrednio jako root jest zablokowane.

**Why this priority**: podstawa hardeningu i element weryfikowany przez Recenzenta.

**Independent Test**: próby logowania na dowolny węzeł różnymi metodami.

**Acceptance Scenarios**:

1. **Given** skonfigurowany węzeł, **When** Administrator loguje się jako `admin` kluczem labu
   (z dozwolonego źródła wg US4), **Then** logowanie się udaje, a polecenie z uprawnieniami root przez sudo
   wykonuje się poprawnie.
2. **Given** skonfigurowany węzeł, **When** ktoś próbuje zalogować się dowolnym kontem z użyciem
   hasła (wymuszając uwierzytelnianie hasłem), **Then** serwer odrzuca próbę bez pytania o hasło
   (dostępne metody nie obejmują hasła).
3. **Given** skonfigurowany węzeł, **When** ktoś próbuje zalogować się jako `root` nawet poprawnym
   kluczem, **Then** logowanie jest odrzucone.
4. **Given** skonfigurowany węzeł, **When** ktoś próbuje zalogować się jako `vagrant` z sieci labu
   (np. z `ops` na 192.168.56.31) nawet poprawnym kluczem, **Then** logowanie jest odrzucone;
   **When** Administrator używa `vagrant ssh` z hosta, **Then** logowanie się udaje; **When**
   ktoś lokalnie próbuje użyć hasła „vagrant” (np. `su - vagrant` z innego konta bez roota),
   **Then** uwierzytelnienie się nie udaje.
5. **Given** szablon konfiguracji SSH z błędem składni, **When** Administrator uruchamia playbook,
   **Then** zadanie kończy się błędem walidacji, a działająca konfiguracja SSH na węźle pozostaje
   niezmieniona i nadal można się zalogować.

---

### User Story 4 - Firewall z domyślną odmową (Priority: P1)

Każdy węzeł odrzuca ruch przychodzący, który nie został jawnie dopuszczony; w etapie 1 dopuszczony
jest wyłącznie dostęp administracyjny ze wskazanego źródła.

**Why this priority**: kryterium ukończenia z planu; fundament dla otwierania portów w kolejnych
etapach.

**Independent Test**: uruchomić testowy nasłuch na porcie spoza listy dozwolonych i próbować się z
nim połączyć z innego węzła.

**Acceptance Scenarios**:

1. **Given** na `db1` działa tymczasowy testowy nasłuch na porcie 3306, **When** z `web1` następuje
   próba połączenia z `db1:3306` z limitem czasu 3 s, **Then** połączenie nie zostaje nawiązane z
   powodu przekroczenia czasu (pakiety są odrzucane bez odpowiedzi), a nie z powodu
   „connection refused”.
2. **Given** ten sam testowy nasłuch, **When** połączenie wykonuje się lokalnie na `db1`,
   **Then** połączenie się udaje (dowód, że nasłuch działa i blokuje go tylko firewall).
3. **Given** skonfigurowane węzły, **When** Administrator łączy się po SSH z `ops` na dowolny
   inny węzeł, **Then** połączenie się udaje; **When** łączy się z innego węzła labu niebędącego
   `ops` (np. z `web1` na `db1`), **Then** połączenie nie zostaje nawiązane (przekroczenie czasu).
4. **Given** skonfigurowane węzły, **When** Administrator łączy się po SSH z hosta na `ops`,
   **Then** połączenie się udaje; **When** łączy się z hosta bezpośrednio na sieciowy adres labu
   innego węzła (np. 192.168.56.31), **Then** połączenie nie zostaje nawiązane.
5. **Given** reguły firewalla zastosowane przez playbook, **When** węzeł zostaje zrestartowany,
   **Then** te same reguły obowiązują po starcie bez ponownego uruchamiania playbooka.
6. **Given** firewall z polityką odmowy, **When** Administrator używa mechanizmu zarządzania
   maszynami (np. `vagrant ssh`, `vagrant halt`), **Then** mechanizm nadal działa (firewall nie
   odcina kanału zarządzania środowiskiem).

---

### User Story 5 - Spójny czas, strefa czasowa i aktualizacje bezpieczeństwa (Priority: P2)

Wszystkie węzły mają tę samą strefę czasową, zsynchronizowany zegar i automatyczne instalowanie
wyłącznie poprawek bezpieczeństwa.

**Why this priority**: Corosync i replikacja MySQL (kolejne etapy) wymagają zgodnego czasu;
aktualizacje bezpieczeństwa to element hardeningu.

**Independent Test**: odczyt stanu synchronizacji czasu i konfiguracji aktualizacji na każdym
węźle.

**Acceptance Scenarios**:

1. **Given** skonfigurowane węzły, **When** Administrator sprawdza status synchronizacji czasu,
   **Then** każdy węzeł raportuje zsynchronizowane źródło czasu, a różnica zegarów między dowolnymi
   dwoma węzłami jest mniejsza niż 1 s.
2. **Given** węzeł, którego zegar został sztucznie przesunięty (symulacja wybudzenia laptopa),
   **When** upłynie do 5 minut, **Then** zegar wraca do synchronizacji bez ręcznej ingerencji.
3. **Given** skonfigurowane węzły, **When** Administrator sprawdza konfigurację automatycznych
   aktualizacji, **Then** obejmuje ona wyłącznie źródła poprawek bezpieczeństwa, a strefa czasowa
   jest identyczna na wszystkich węzłach.
4. **Given** skonfigurowane węzły, **When** Administrator sprawdza konfigurację aktualizacji
   i uruchamia polecenie sygnalizujące potrzebę restartu, **Then** konfiguracja wyklucza
   automatyczny restart (zarówno po aktualizacji, jak i po restarcie usług), a polecenie
   kończy się sukcesem i zwraca jednoznaczny stan („restart niewymagany” albo „wymagany”).
   Opcjonalna symulacja: **Given** zainstalowane jądro nowsze od działającego, **When**
   Administrator uruchamia to samo polecenie, **Then** zwraca stan „wymagany”, a węzeł nie
   restartuje się sam.
5. **Given** skonfigurowane węzły, **When** Administrator sprawdza listę zainstalowanych narzędzi,
   **Then** na każdym węźle są dostępne: edytor `vim`, `htop`, `curl`, `rsync`, `tcpdump`.

---

### User Story 6 - Automatyczna kontrola jakości kodu (Priority: P2)

Każde wypchnięcie zmian do repozytorium uruchamia lintery YAML i Ansible; błędny kod jest
wykrywany przed scaleniem do `main`.

**Why this priority**: wymaganie konstytucji (zasada III, sekcja Git); nie blokuje działania
klastra, ale blokuje merge.

**Independent Test**: wypchnąć gałąź z celowo błędnym YAML-em i sprawdzić wynik w CI.

**Acceptance Scenarios**:

1. **Given** repozytorium bez błędów lintowania, **When** Administrator wypycha zmiany,
   **Then** zadanie CI kończy się sukcesem.
2. **Given** gałąź z celowo wprowadzonym błędem (np. zła indentacja lub zadanie bez nazwy),
   **When** zostaje wypchnięta, **Then** zadanie CI kończy się porażką ze wskazaniem pliku i
   linii, a pull request nie może zostać scalony.
3. **Given** lokalne hooki przed commitem, **When** Administrator próbuje zatwierdzić plik z
   błędnym YAML-em, **Then** commit jest zablokowany z komunikatem lintera.

---

### User Story 7 - Dokumentacja etapu jako tutorial (Priority: P3)

Recenzent odtwarza etap 1 wyłącznie na podstawie dokumentacji, bez kontaktu z autorem.

**Why this priority**: zasada VI konstytucji; wartość portfolio.

**Independent Test**: osoba trzecia przechodzi tutorial na czystym hoście.

**Acceptance Scenarios**:

1. **Given** dokumentacja etapu 1, **When** Recenzent ją czyta, **Then** każdy krok zawiera: co,
   dlaczego, komendę, weryfikację z oczekiwanym wynikiem i typowe problemy.
2. **Given** czysty host spełniający wymagania, **When** Recenzent wykonuje tutorial krok po kroku,
   **Then** dochodzi do środowiska spełniającego scenariusze US1–US5 bez pytań do autora.
3. **Given** decyzje z sekcji Clarifications (system, hiperwizor, węzeł sterujący, klucze labu, konto `vagrant`, restarty po aktualizacjach) oraz rozwiązanie sprzeczności firewalla, **When** etap jest zamykany,
   **Then** każda z nich ma ADR w `docs/adr/`.

---

### Edge Cases

- **Zablokowanie samego siebie**: zastosowanie polityki „drop” albo wyłączenie logowania hasłem
  przed potwierdzeniem, że klucz `admin` działa i źródło SSH jest dopuszczone, odcina dostęp.
  Kolejność zmian MUSI wykluczać utratę dostępu w trakcie przebiegu.
- **Interfejs NAT środowiska wirtualizacji**: wszystkie maszyny mogą mieć ten sam adres NAT; ruch
  zarządzający (np. `vagrant ssh`) przychodzi tym interfejsem. Firewall nie może go odcinać, a
  inventory i `/etc/hosts` nie mogą go używać.
- **Nazwa hosta na `127.0.1.1`**: domyślne obrazy mapują własną nazwę hosta na pętlę zwrotną —
  znany problem dla Corosync w etapie 4; musi być naprawiony już tutaj.
- **Konto domyślne obrazu** (`vagrant` z publicznie znanym hasłem i sudo bez hasła): usunięte
  zepsułoby zarządzanie środowiskiem, pozostawione bez ograniczeń osłabia hardening —
  rozstrzygnięte w FR-008a.
- **Nowe poprawki między przebiegami**: drugi przebieg może wykryć nowe aktualizacje i zgłosić
  `changed>0` mimo poprawnej konfiguracji (patrz FR-012).
- **VirtualBox obok Hyper-V** (Docker Desktop/WSL2 na tym samym Windowsie): maszyny mogą
  startować wolno lub zawieszać się; dokumentacja MUSI opisać objaw, sprawdzenie i obejście
  (np. wyłączenie Hyper-V na czas pracy z labem) w sekcji „Typowe problemy”.
- **Bootstrap `ops`**: zanim `ops` skonfiguruje inne węzły, musi mieć Ansible, kod repozytorium i
  klucz do łączenia się z węzłami. Klucz prywatny nie może trafić do repozytorium (zasada IV);
  repozytorium trafia na `ops` przez folder współdzielony (FR-005a), a klucz — przez
  automatycznie generowaną parę kluczy labu (FR-007a), bez ręcznych kroków.
- **Folder współdzielony niedostępny lub z błędnymi uprawnieniami** (np. brak dodatków gościa
  VirtualBoxa w obrazie, katalog z prawem zapisu dla wszystkich): przebieg z `ops` nie może
  cicho zignorować konfiguracji z repozytorium — Administrator dostaje jednoznaczny błąd lub
  ostrzeżenie opisane w „Typowych problemach”.
- **Brak pamięci hosta**: utworzenie 7 maszyn przy niewystarczającej pamięci kończy się
  częściowym środowiskiem; dokumentacja MUSI podać minimalne wymagania pamięci hosta i objaw
  ich niespełnienia. Wariant zredukowany (bez `ops`) nie jest wspierany (FR-005, ADR 0003).
- **Restart węzła w trakcie przebiegu** lub niedostępność repozytorium pakietów: przebieg kończy
  się błędem z czytelnym komunikatem; ponowne uruchomienie dokańcza konfigurację.
- **Rozjechany zegar po uśpieniu hosta** (z planu, sekcja 13): obsłużone przez US5 scenariusz 2.

## Requirements *(mandatory)*

### Functional Requirements

**Środowisko**

- **FR-001**: Repozytorium MUSI zawierać definicję środowiska tworzącą 7 maszyn
  (`ops`, `lb1`, `lb2`, `web1`, `web2`, `db1`, `db2`) z nazwami, adresami IP w sieci
  192.168.56.0/24 i pamięcią zgodnymi z tabelą architektury, zdefiniowanymi w jednym miejscu
  (lista maszyn), bez powielania konfiguracji per maszyna.
- **FR-002**: Środowisko MUSI być tworzone przez Vagranta uruchamianego na hoście Windows z
  providerem VirtualBox; wersje Vagranta i VirtualBoxa użyte do testów MUSZĄ być zapisane w
  dokumentacji.
- **FR-003**: Wszystkie maszyny MUSZĄ używać Debiana 13 (trixie) z obrazu bazowego o przypiętej
  wersji.
- **FR-004**: Inventory MUSI definiować grupy `lb`, `web`, `db`, `ops` i adresować hosty adresami
  z sieci labu.
- **FR-005**: Węzeł `ops` MUSI być węzłem sterującym: po utworzeniu środowiska zawiera Ansible
  (w wersji zgodnej z planem), kolekcje z `requirements.yml` oraz kod repozytorium, a główny
  playbook jest uruchamiany z `ops`. Wariant bez `ops` nie jest wspierany; dokumentacja podaje
  minimalne wymagania pamięci hosta dla 7 maszyn.
- **FR-005a**: Kod repozytorium MUSI być dostępny na `ops` przez folder współdzielony z hosta
  (zmiana pliku na hoście jest widoczna na `ops` bez dodatkowych kroków). Uruchomienie playbooka
  z tego folderu MUSI korzystać z konfiguracji Ansible z repozytorium mimo uprawnień plików
  narzucanych przez folder współdzielony (Ansible nie może pominąć jej z ostrzeżeniem).

**Konfiguracja bazowa (wszystkie węzły)**

- **FR-006**: Konfiguracja MUSI instalować zestaw narzędzi bazowych: `vim`, `htop`, `curl`,
  usługę synchronizacji czasu, `rsync`, `tcpdump`.
- **FR-007**: Konfiguracja MUSI tworzyć konto `admin` z logowaniem kluczem publicznym i sudo,
  akceptujące klucz labu.
- **FR-007a**: Przy pierwszym tworzeniu środowiska MUSI automatycznie powstać dedykowana para
  kluczy labu w katalogu ignorowanym przez Git; istniejąca para jest używana ponownie przy
  kolejnych odtworzeniach. Klucz publiczny trafia na wszystkie węzły podczas ich tworzenia
  (umożliwia pierwszą konfigurację z `ops`), a klucz prywatny jest kopiowany na `ops` z
  uprawnieniami akceptowanymi przez klienta SSH — nie jest używany bezpośrednio z folderu
  współdzielonego. Klucz prywatny nigdy nie trafia do repozytorium (zasada IV).
- **FR-008**: Konfiguracja SSH MUSI być generowana w całości z szablonu, z wyłączonym logowaniem
  hasłem i logowaniem roota, i MUSI być walidowana przed zastosowaniem; restart usługi SSH
  następuje tylko po faktycznej zmianie konfiguracji.
- **FR-008a**: Domyślne konto obrazu (`vagrant`) MUSI pozostać (wymaga go mechanizm zarządzania
  środowiskiem), ale MUSI mieć zablokowane hasło, a serwer SSH MUSI wpuszczać je wyłącznie
  kluczem i wyłącznie z kanału zarządzania Vagranta (interfejs NAT), nigdy z sieci labu.
  Ograniczenie i wariant produkcyjny (brak takiego konta) są opisane w ADR.
- **FR-009**: Konfiguracja MUSI ustawiać jednolitą strefę czasową (domyślnie UTC — patrz
  Założenia) i synchronizację czasu na wszystkich węzłach.
- **FR-010**: Plik rozwiązywania nazw hostów MUSI być generowany z inventory i zawierać wszystkie
  węzły labu z adresami z sieci 192.168.56.0/24 oraz adres VIP; własna nazwa węzła nie może
  wskazywać na adres pętli zwrotnej.
- **FR-011**: Firewall MUSI mieć domyślną politykę odrzucania ruchu przychodzącego i w etapie 1
  dopuszczać wyłącznie: ruch na interfejsie pętli zwrotnej, ruch powiązany z nawiązanymi
  połączeniami, SSH z `ops` (na węzłach innych niż `ops`), SSH z adresu hosta 192.168.56.1
  (tylko na `ops`) oraz kanał zarządzania środowiskiem wirtualizacji.
  Porty usług z tabeli architektury są otwierane przez role etapów, które te usługi wprowadzają.
  Reguły MUSZĄ być trwałe po restarcie i definiowane w sposób pozwalający kolejnym rolom
  dodawać własne porty bez edycji roli bazowej.
- **FR-012**: Węzły MUSZĄ automatycznie instalować wyłącznie poprawki bezpieczeństwa. Jednorazowa
  aktualizacja pakietów przy pierwszej konfiguracji jest dopuszczalna, ale kolejne przebiegi
  playbooka NIE MOGĄ wykonywać pełnej aktualizacji systemu (warunek `changed=0`).
  Automatyczne aktualizacje NIE MOGĄ restartować węzła; jeśli poprawka wymaga restartu, węzeł
  MUSI to sygnalizować w sposób sprawdzalny jednym poleceniem, a restart wykonuje Administrator
  ręcznie (w etapie 4 — według runbooka obsługi węzła LB).

**Jakość i proces**

- **FR-013**: Drugi przebieg głównego playbooka MUSI dać `changed=0` i `failed=0` na wszystkich
  hostach (zasada II).
- **FR-014**: Pełne odtworzenie od zera (zniszczenie → utworzenie → konfiguracja) MUSI zakończyć
  się bez błędów; wynik obu przebiegów trafia do opisu pull requesta etapu.
- **FR-015**: Repozytorium MUSI mieć lokalne hooki przed commitem oraz CI uruchamiające lintery
  YAML i Ansible przy każdym pushu.
- **FR-016**: Zmiany w konfiguracji bazowej MUSZĄ dać się zastosować selektywnie (np. tylko część
  SSH lub tylko firewall) przez tagi.
- **FR-017**: Każda decyzja z sekcji Clarifications oraz rozwiązanie sprzeczności firewalla MUSZĄ mieć ADR w
  `docs/adr/`; dokumentacja etapu MUSI mieć formę tutorialu (zasada VI); problemy napotkane
  podczas pracy trafiają do `docs/notes.md`.
- **FR-018**: Kolejność zadań konfiguracji MUSI wykluczać utratę dostępu administracyjnego w
  trakcie przebiegu (konto `admin` i reguła SSH przed zablokowaniem haseł i polityką „drop”).

### Key Entities

- **Węzeł**: maszyna labu; atrybuty: nazwa, adres IP w sieci labu, pamięć, grupa (rola w
  klastrze).
- **Grupa inventory**: `lb`, `web`, `db`, `ops`; podstawa zmiennych i otwieranych portów.
- **Reguła dostępu**: port/protokół + dozwolone źródło + węzeł docelowy + etap, który ją
  wprowadza.
- **Konto administracyjne**: `admin`, klucz publiczny labu, uprawnienia sudo.
- **Para kluczy labu**: generowana raz na kopię środowiska, poza Gitem; publiczna na wszystkich
  węzłach, prywatna na hoście i na `ops`.
- **ADR**: zapis decyzji (z sekcji Clarifications oraz firewall) zgodny z zasadą V.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Pełne odtworzenie środowiska od zera kończy się bez błędów w 3 kolejnych próbach
  z rzędu.
- **SC-002**: 100% hostów (7/7) raportuje `changed=0` i `failed=0` w drugim przebiegu po każdym
  odtworzeniu.
- **SC-003**: Czas od polecenia „utwórz” do zakończenia pierwszego przebiegu konfiguracji jest
  udokumentowany i nie przekracza 30 minut na sprzęcie z sekcji „Wymagania sprzętowe” planu.
- **SC-004**: 0 udanych prób logowania hasłem lub jako root na 7 węzłach (test każdego węzła).
- **SC-005**: 0 udanych połączeń na porty spoza listy dozwolonych w testach z US4; testy
  odróżniają blokadę firewalla od braku usługi.
- **SC-006**: Maksymalna różnica zegarów między węzłami < 1 s.
- **SC-007**: CI wykrywa 100% celowo wprowadzonych błędów lintowania w teście z US6.
- **SC-008**: Osoba trzecia odtwarza etap 1 z dokumentacji bez pytań do autora (co najmniej
  jedna próba przed zamknięciem projektu; każde miejsce, w którym utknęła, jest poprawione).

## Assumptions

- **Firewall w etapie 1**: otwierany jest tylko SSH (i kanał zarządzania środowiskiem); porty
  usług otwierają role kolejnych etapów. Rozwiązuje to sprzeczność planu na korzyść kryterium
  ukończenia i zasady „tylko porty potrzebne, tylko dla wskazanych źródeł”.
- **Strefa czasowa**: UTC na wszystkich węzłach (spójne logi i korelacja zdarzeń w przyszłym
  ELK); czas lokalny jest kwestią prezentacji.
- **Klucz SSH `admin`**: jedna para kluczy labu na kopię środowiska (FR-007a); każdy Recenzent
  dostaje własną parę przy pierwszym tworzeniu środowiska. Utrata pary = usunięcie katalogu
  kluczy i pełne odtworzenie od zera.
- **Adres hosta w sieci labu**: host ma w sieci host-only VirtualBoxa stały adres 192.168.56.1
  (domyślny dla tej sieci); jeśli na danym komputerze jest inny, dokumentacja opisuje, jak go
  sprawdzić i nadpisać w jednej zmiennej. SSH z hosta do `ops` korzysta z tego adresu albo z
  `vagrant ssh`.
- **Sekrety**: etap 1 nie wymaga sekretów (logowanie kluczem), więc nie tworzy jeszcze
  zaszyfrowanego `vault.yml` — powstaje on w etapie 2 wraz z pierwszym sekretem (research R15).
  Już w etapie 1 `.gitignore` zawiera plik hasła do vaulta, a README opisuje, jak go utworzyć
  (zasada IV).
- **Repozytorium zdalne**: CI wymaga publicznego repozytorium na GitHubie; jego utworzenie i
  inicjalizacja Git są warunkiem wstępnym US6 (katalog projektu nie jest jeszcze repozytorium Git).
- **Zakres**: etap 1 nie instaluje żadnych usług aplikacyjnych (MySQL, Docker, Nginx, HAProxy,
  Pacemaker) — należą do etapów 2–4.
- **Monitoring zmian dryfu konfiguracji** poza ręcznym `--check --diff` jest poza zakresem.
