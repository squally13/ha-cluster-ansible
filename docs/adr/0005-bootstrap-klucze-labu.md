# 0005. Bootstrap: para kluczy labu i konto `admin` przed Ansible

- **Status**: Przyjęty
- **Data**: 2026-11-09
- **Etap**: 1

## Kontekst

Problem „jajka i kury”: Ansible na `ops` musi zalogować się do węzłów, zanim cokolwiek na nich
skonfiguruje. Konto `vagrant` nie może być używane z sieci labu (FR-008a), a w repo nie może być
klucza prywatnego (zasada IV). Clarify Q3, decyzja R5.

## Decyzja

1. Przy pierwszym `vagrant up` `Vagrantfile` generuje parę `ed25519` bez hasła w `.lab/ssh/`
   (`ssh-keygen` wbudowany w Windows 10/11). Katalog `.lab/` jest w `.gitignore`.
2. Provisioner `vagrant/bootstrap-node.sh` (idempotentny) na każdym węźle tworzy konto `admin`,
   `authorized_keys` z kluczem publicznym labu (przekazanym jako argument, nie przez folder
   współdzielony) i `/etc/sudoers.d/admin` o treści identycznej z szablonem roli `common`.
3. Na `ops` dodatkowo `vagrant/bootstrap-ops.sh`: venv `/opt/ansible` z przypiętym
   `ansible-core`, kolekcje z `requirements.yml`, kopia klucza prywatnego do
   `~admin/.ssh/id_ed25519` (`0600`, poza `vboxsf`).
4. Dalej konto utrzymuje rola `common` — bootstrap tworzy dokładnie ten stan, który rola
   deklaruje, więc pierwszy przebieg nie raportuje zmian na koncie `admin`.

## Rozważane alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| Pierwsze połączenie jako `vagrant` | zero bootstrapu | `vagrant` musiałby logować się z sieci labu | sprzeczne z FR-008a |
| Provisioner `ansible_local` | Ansible od początku | ukrywa przebieg w `vagrant up`, utrudnia drugi przebieg i tagi | Ansible ma być uruchamiany jawnie z `ops` |
| Klucz w repo (zaszyfrowany vaultem) | brak generowania | hasło vaulta potrzebne już do `vagrant up` | zbędna komplikacja; klucz labu jest jednorazowy |
| Hasło `admin` zamiast klucza | proste | łamie FR-008 | — |

## Konsekwencje

- **Pozytywne**: pierwszy `vagrant up` daje gotowe środowisko do `ansible all -m ping`; klucz
  nigdy nie trafia do Git.
- **Negatywne / ograniczenia**: bootstrap powłoki to drugi (mały) mechanizm konfiguracji poza
  Ansible — musi pozostać minimalny i zgodny z rolą; usunięcie `.lab/` wymaga odtworzenia labu
  od zera; klucz bez hasła.
- **Co byłoby inaczej na produkcji**: konta i klucze z systemu tożsamości (FreeIPA/LDAP, certyfikaty
  SSH z krótką ważnością), obraz z wbudowanym kontem automatyzacji (cloud-init).
