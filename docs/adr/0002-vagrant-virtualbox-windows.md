# 0002. Vagrant + VirtualBox na Windowsie, repozytorium na NTFS

- **Status**: Przyjęty
- **Data**: 2026-11-09
- **Etap**: 1

## Kontekst

Lab ma 7 maszyn na jednym hoście Windows (16 GB RAM). Środowisko musi powstawać jednym poleceniem
i dawać się zniszczyć i odtworzyć (zasada II). Na hoście może działać Hyper-V (WSL2, Docker
Desktop). Pytanie Q1 ze spec; decyzje R1 i R14 z research.

## Decyzja

- Vagrant 2.4.x i VirtualBox 7.x uruchamiane **na Windowsie** (PowerShell).
  Zweryfikowane wersje: VirtualBox `7.2.16r174877`; Vagrant — *do uzupełnienia po instalacji*.
- Repozytorium leży na NTFS (`C:\Users\<user>\projects\ha-homelab`), bo folder współdzielony
  VirtualBoxa nie obsługuje ścieżek `\\wsl$\...`. `.gitattributes` wymusza LF.
- Najpierw praca z włączonym Hyper-V (VirtualBox przez Windows Hypervisor Platform). Jeśli czas
  z SC-003 przekroczy 30 min albo maszyny się zawieszają — `bcdedit /set hypervisorlaunchtype off`
  i restart (wyłącza też WSL2 i Docker Desktop na czas pracy z labem).
- Narzędzia lintu (`pre-commit`, `ansible-lint`) uruchamiane z WSL na `/mnt/c/...`, bo
  `ansible-core` nie działa natywnie na Windowsie.

**Pomiar SC-003** (od `vagrant up` do końca pierwszego `site.yml`): *do uzupełnienia w T065*.

## Rozważane alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| Hyper-V jako provider Vagranta | natywny na Windowsie | słabe sieci prywatne (brak host-only ze stałymi IP), brak `vboxsf` | sieć 192.168.56.0/24 ze stałymi adresami jest podstawą planu |
| Vagrant w WSL (`VAGRANT_WSL_ENABLE_WINDOWS_ACCESS`) | jedno środowisko Linux | kruche ścieżki, problemy z uprawnieniami i synced folders | odrzucone w Q1 |
| Repo w WSL + rsync na NTFS | szybki system plików | dwie kopie, dodatkowy krok przed każdym `vagrant up` | ryzyko pracy na nieaktualnej kopii |
| Proxmox / osobny serwer | realistyczny | dodatkowy sprzęt | poza budżetem projektu |

## Konsekwencje

- **Pozytywne**: jedno polecenie `vagrant up` tworzy cały lab; recenzent z Windowsem odtworzy go
  bez dodatkowego sprzętu.
- **Negatywne / ograniczenia**: VirtualBox na Hyper-V bywa wolniejszy; ~7 GB RAM tylko dla labu;
  hook pre-commit działa tylko przy commitach z WSL (Git for Windows nie uruchomi `ansible-lint`).
- **Co byłoby inaczej na produkcji**: hiperwizor klasy serwerowej (Proxmox, VMware, chmura) i
  maszyny tworzone przez Terraform, nie Vagranta.
