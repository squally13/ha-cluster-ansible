# Kontrakt: fragmenty reguł firewalla dla kolejnych ról

Rola `common` udostępnia kolejnym rolom (etapy 2–5) sposób otwierania portów **bez edycji roli
bazowej** (FR-011).

## Gwarancje roli `common`

1. `/etc/nftables.conf` zaczyna się od `flush ruleset`, definiuje tabelę `inet filter` z
   łańcuchem `input` (`type filter hook input priority 0; policy drop;`) i **po** definicji
   tabeli, na najwyższym poziomie pliku, dołącza fragmenty: `include "/etc/nftables.d/*.nft"`.
   Cały plik jest ładowany jedną transakcją, więc nie ma stanu pośredniego.
2. Katalog `/etc/nftables.d/` istnieje (`root:root`, `0755`).
3. Handler `Reload nftables` (wywoływany przez `notify`) ładuje cały zestaw reguł atomowo
   (`nft -f /etc/nftables.conf`) i jest dostępny dla innych ról przez `listen: reload firewall`.
4. Usługa `nftables` jest włączona, więc reguły obowiązują po restarcie.

## Obowiązki roli dokładającej reguły

1. Szablon `roles/<rola>/templates/nftables.nft.j2` → `/etc/nftables.d/<rola>.nft`,
   `owner: root`, `mode: "0644"`, nagłówek „Zarządzane przez Ansible”.
2. Zawartość: wyłącznie polecenia `add rule inet filter input ...` (bez definicji tabel,
   łańcuchów i bez `flush`), np.:

   ```nft
   # Zarządzane przez Ansible — rola mysql
   add rule inet filter input ip saddr { 192.168.56.21, 192.168.56.22, 192.168.56.32 } tcp dport 3306 accept comment "mysql: web + replika"
   ```

3. Źródła wyliczane z inventory (np. `groups['web']` → `hostvars[h].ansible_host`), nigdy
   wpisane ręcznie.
4. Każda reguła ma `comment` z nazwą roli.
5. `validate:` — fragment nie jest samodzielnie poprawnym plikiem, więc walidacja całości
   następuje w handlerze: `nft -c -f /etc/nftables.conf` przed `nft -f`; błąd walidacji przerywa
   przebieg, a załadowany zestaw reguł pozostaje bez zmian.
6. `notify: reload firewall`.
7. Zakaz: polityka `accept`, reguły bez źródła (`tcp dport X accept` dla całego świata), edycja
   `/etc/nftables.conf`.

## Weryfikacja kontraktu

- `nft list chain inet filter input` na węźle pokazuje reguły bazowe + reguły z komentarzami
  ról, polityka `drop`.
- Drugi przebieg `site.yml`: `changed=0`.
