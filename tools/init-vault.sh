#!/usr/bin/env bash
# Inicjalizacja Ansible Vault labu (etap 2, research R7, ADR 0013).
#
# Tworzy własne hasło do Vaulta (.vault_pass, poza Gitem) i zaszyfrowany
# inventories/lab/group_vars/all/vault.yml z losowymi hasłami kont MySQL.
# Dla Recenzenta: repozytorium zawiera vault.yml zaszyfrowany hasłem autora — uruchom ten skrypt
# z --force, żeby zastąpić go własnym (zmiana zostaje lokalnie; nie commituj jej).
#
# Uruchamiaj na HOŚCIE w WSL, w katalogu repo, z venv narzędzi lintu (zawiera ansible-vault):
#   source ~/.venvs/ha-homelab/bin/activate && tools/init-vault.sh [--force]
# Nie na ops: tam repo jest w folderze współdzielonym tylko do odczytu dla admin (ADR 0008);
# ops jedynie czyta .vault_pass przez ANSIBLE_VAULT_PASSWORD_FILE.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS_FILE="$REPO/.vault_pass"
VAULT_FILE="$REPO/inventories/lab/group_vars/all/vault.yml"
FORCE=0

case "${1:-}" in
  --force) FORCE=1 ;;
  "") ;;
  *) echo "Użycie: $0 [--force]" >&2; exit 2 ;;
esac

command -v ansible-vault >/dev/null || { echo "Brak ansible-vault — aktywuj venv: source ~/.venvs/ha-homelab/bin/activate" >&2; exit 1; }

if [[ -e "$VAULT_FILE" && $FORCE -eq 0 ]]; then
  echo "$VAULT_FILE już istnieje — nie nadpisuję. Użyj --force, żeby utworzyć nowy (stare hasła przepadną)." >&2
  exit 1
fi

# Losowy ciąg z liter i cyfr (bez znaków wymagających cytowania w SQL/YAML/powłoce)
random_secret() {
  python3 -c "import secrets,string; a=string.ascii_letters+string.digits; print(''.join(secrets.choice(a) for _ in range($1)))"
}

if [[ ! -s "$PASS_FILE" || $FORCE -eq 1 ]]; then
  umask 077
  random_secret 32 > "$PASS_FILE"
  chmod 600 "$PASS_FILE" 2>/dev/null || true  # na NTFS (/mnt/c) chmod nie działa — plik i tak poza Gitem
  echo "Utworzono $PASS_FILE (poza Gitem — .gitignore)."
fi

tmp="$(mktemp)"
# Na /mnt/c każdy plik ma bit wykonywalności, a Ansible uruchamia „wykonywalny” plik hasła jak
# skrypt — dlatego hasło podajemy przez kopię 0600 poza NTFS (na ops plik ma 0644 i działa wprost).
pass_copy="$(mktemp)"
trap 'rm -f "$tmp" "$pass_copy"' EXIT
cat "$PASS_FILE" > "$pass_copy"
cat > "$tmp" <<EOF
---
# Sekrety labu (zasada IV). Edycja: ansible-vault edit inventories/lab/group_vars/all/vault.yml
vault_mysql_repl_password: "$(random_secret 24)"
vault_mysql_clone_password: "$(random_secret 24)"
vault_mysql_app_password: "$(random_secret 24)"
EOF
ansible-vault encrypt --vault-password-file "$pass_copy" --output "$VAULT_FILE" "$tmp"
echo "Utworzono zaszyfrowany $VAULT_FILE (3 hasła). Podgląd na ops: ansible-vault view $VAULT_FILE"
