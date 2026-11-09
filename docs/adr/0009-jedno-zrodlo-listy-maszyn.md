# 0009. Jedno źródło listy maszyn: `hosts.yml` czytany przez Vagrantfile

- **Status**: Przyjęty
- **Data**: 2026-11-09
- **Etap**: 1

## Kontekst

Lista maszyn (nazwa, IP, RAM, grupa) jest potrzebna i Vagrantowi (tworzenie VM), i Ansible
(inventory). Duplikacja grozi rozjazdem (np. inny IP w dwóch plikach). Dodatkowo Vagrant przy
`config.vm.hostname` dopisuje nazwę hosta na `127.0.1.1`, co w etapie 4 psuje Corosync (węzeł
ogłasza się adresem pętli zwrotnej) i daje dryf w `/etc/hosts`. R3, R4.

## Decyzja

- `inventories/lab/hosts.yml` jest **jedynym** źródłem listy maszyn. `Vagrantfile` czyta go
  (YAML) i w pętli tworzy maszyny; RAM to zmienna hosta `vagrant_memory`.
- `Vagrantfile` **nie** ustawia `config.vm.hostname`. Nazwę hosta ustawia rola `common`
  (`ansible.builtin.hostname`), a `/etc/hosts` jest w całości generowany z inventory (wszystkie
  węzły + `vip`), bez linii `127.0.1.1`.

## Rozważane alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| Lista w Vagrantfile + generowane inventory | Vagrant jako źródło | inventory staje się artefaktem; trudniejsze do czytania i przeglądu w PR | inventory jest ważniejsze dla dalszych etapów |
| Lista w obu plikach | najprostsze | ryzyko rozjazdu | łamie zasadę jednego źródła prawdy |
| `config.vm.hostname` + nadpisywanie `/etc/hosts` | nazwa od razu po `vagrant up` | dwa narzędzia walczą o ten sam plik; `changed` po każdym `vagrant reload` | łamie idempotencję |

## Konsekwencje

- **Pozytywne**: dodanie węzła (runbook `add-web-node` w kolejnych etapach) to zmiana jednego
  pliku; `/etc/hosts` jest przewidywalny.
- **Negatywne / ograniczenia**: do pierwszego przebiegu `site.yml` węzły mają nazwę z obrazu;
  Ansible ostrzega „Found both group and host with same name: ops” (grupa i host o tej samej
  nazwie — celowe, ostrzeżenie nieszkodliwe).
- **Co byłoby inaczej na produkcji**: inventory dynamiczne z CMDB/chmury (np. plugin inventory
  dostawcy), DNS zamiast `/etc/hosts`.
