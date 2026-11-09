# 0004. Firewall: nftables, w etapie 1 tylko SSH, porty usług otwierane przez role etapów

- **Status**: Przyjęty
- **Data**: 2026-11-09
- **Etap**: 1

## Kontekst

Plan projektu jest sprzeczny: krok 4 etapu 1 każe od razu otworzyć porty usług (80, 3306, …), a
kryterium akceptacji mówi, że połączenie `web1 → db1:3306` ma być zablokowane, dopóki baza nie
istnieje. Dodatkowo kolejne etapy muszą otwierać porty bez edycji roli bazowej (FR-011).

## Decyzja

- Firewall to **nftables** (domyślny w Debianie 13). `/etc/nftables.conf` z szablonu roli
  `common`: `flush ruleset`, tabela `inet filter`, łańcuch `input` z polityką `drop`, `forward`
  `drop`, `output` `accept`; reguły bazowe: loopback, `established,related`, `invalid drop`.
- **W etapie 1 otwarte jest wyłącznie SSH**: z `ops` do węzłów, z hosta do `ops` oraz kanał
  zarządzania Vagranta na interfejsie NAT. Porty usług otwiera rola danego etapu.
- Mechanizm rozszerzeń: na końcu `nftables.conf` jest `include "/etc/nftables.d/*.nft"`.
  Role kolejnych etapów dokładają pliki z poleceniami `add rule inet filter input ...` (kontrakt
  `specs/001-etap1-fundament/contracts/firewall-dropin.md`). Rola `common` tworzy
  `00-common.nft` (sam komentarz), żeby wzorzec zawsze miał dopasowanie.
- Ładowanie atomowe przez handler (`nft -c -f` → `nft -f`) — brak stanu pośredniego, w którym
  polityka `drop` obowiązuje bez reguły SSH (FR-018).
- ICMP echo z sieci labu jest zamknięty (FR-011 mówi „wyłącznie”); komunikaty błędów ICMP
  przechodzą jako `related`. Test łączności to moduł `ping` Ansible (SSH), nie ICMP.

## Rozważane alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| Otworzyć wszystkie porty usług w etapie 1 | zgodne z krokiem 4 planu | łamie kryterium 3306; porty otwarte bez usług | „najmniejsze uprawnienia” i testowalność |
| firewalld | strefy, popularny w RHEL | nie jest domyślny w Debianie; strefy komplikują reguły per źródło | zbędna warstwa |
| ufw | prosty | nakładka, mniej przejrzyste reguły i atomowość | słabsza kontrola nad kolejnością |
| Lista reguł w zmiennej scalanej z `group_vars` | wszystko w jednym pliku | Ansible nie scala list między rolami — kruche | fragmenty są niezależne od siebie |

## Konsekwencje

- **Pozytywne**: każdy etap pokazuje w PR, które porty i z jakich źródeł otwiera; test US4
  odróżnia blokadę (`timeout`) od braku usługi (`refused`).
- **Negatywne / ograniczenia**: brak ICMP utrudnia szybką diagnostykę (`ping` nie działa między
  węzłami); fragment z błędem składni zatrzymuje przeładowanie dla wszystkich ról (celowo).
- **Co byłoby inaczej na produkcji**: dodatkowo firewall sieciowy / security groups, reguły
  wyjściowe (`output` nie byłby `accept`), logowanie odrzuconych pakietów do SIEM.
