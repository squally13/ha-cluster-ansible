#!/usr/bin/env bash
# Bootstrap każdego węzła (R5): konto admin z kluczem publicznym labu i sudo bez hasła.
# Idempotentny — ponowne uruchomienie nie zmienia stanu. Dalej konto utrzymuje rola common.
# Użycie: bootstrap-node.sh "<klucz publiczny labu>"
set -euo pipefail

if [[ $# -ne 1 || -z "$1" ]]; then
  echo "Użycie: $0 \"<klucz publiczny labu>\"" >&2
  exit 2
fi
PUBKEY="$1"
ADMIN_USER="admin"

# 1. Konto admin
if ! id -u "$ADMIN_USER" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "$ADMIN_USER"
  echo "bootstrap: utworzono konto $ADMIN_USER"
fi
ADMIN_HOME="$(getent passwd "$ADMIN_USER" | cut -d: -f6)"

# 2. Klucz publiczny labu
install -d -m 0700 -o "$ADMIN_USER" -g "$ADMIN_USER" "$ADMIN_HOME/.ssh"
AUTH_KEYS="$ADMIN_HOME/.ssh/authorized_keys"
if [[ ! -f "$AUTH_KEYS" ]] || ! grep -qxF "$PUBKEY" "$AUTH_KEYS"; then
  printf '%s\n' "$PUBKEY" > "$AUTH_KEYS"
  echo "bootstrap: zapisano klucz publiczny labu"
fi
chown "$ADMIN_USER:$ADMIN_USER" "$AUTH_KEYS"
chmod 0600 "$AUTH_KEYS"

# 3. sudo bez hasła — treść identyczna z roles/common/templates/sudoers_admin.j2
SUDOERS_FILE="/etc/sudoers.d/admin"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
cat > "$TMP" <<SUDOERS
# Zarządzane przez Ansible — nie edytuj ręcznie
$ADMIN_USER ALL=(ALL) NOPASSWD:ALL
SUDOERS
if ! cmp -s "$TMP" "$SUDOERS_FILE"; then
  visudo -cf "$TMP" >/dev/null
  install -m 0440 -o root -g root "$TMP" "$SUDOERS_FILE"
  echo "bootstrap: zapisano $SUDOERS_FILE"
fi
chown root:root "$SUDOERS_FILE"
chmod 0440 "$SUDOERS_FILE"
