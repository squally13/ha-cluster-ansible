#!/usr/bin/env bash
# Bootstrap węzła sterującego ops (R5, R6): Ansible w venv /opt/ansible, kolekcje, klucz prywatny
# labu dla admin, ANSIBLE_CONFIG i ANSIBLE_VAULT_PASSWORD_FILE w profilu. Idempotentny.
set -euo pipefail

ADMIN_USER="admin"
VENV="/opt/ansible"
REPO="/vagrant"
ADMIN_HOME="$(getent passwd "$ADMIN_USER" | cut -d: -f6)"

# 1. Pakiety potrzebne do venv i pracy z repo
if ! dpkg -s python3-venv git >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -q
  apt-get install -y -q python3-venv git
fi

# 2. Ansible w wirtualnym środowisku Pythona, z przypiętych wersji
if [[ ! -x "$VENV/bin/python" ]]; then
  python3 -m venv "$VENV"
fi
"$VENV/bin/pip" install --quiet --disable-pip-version-check -r "$REPO/requirements-ops.txt"
for bin in "$VENV"/bin/ansible*; do
  ln -sfn "$bin" "/usr/local/bin/$(basename "$bin")"
done

# 3. Kolekcje (instalowane dla admin; ansible-galaxy pomija już zainstalowane wersje)
sudo -u "$ADMIN_USER" -H "$VENV/bin/ansible-galaxy" collection install -r "$REPO/requirements.yml"

# 4. Klucz prywatny labu — kopia poza vboxsf, z właściwymi uprawnieniami
install -d -m 0700 -o "$ADMIN_USER" -g "$ADMIN_USER" "$ADMIN_HOME/.ssh"
if ! cmp -s "$REPO/.lab/ssh/id_ed25519" "$ADMIN_HOME/.ssh/id_ed25519"; then
  install -m 0600 -o "$ADMIN_USER" -g "$ADMIN_USER" "$REPO/.lab/ssh/id_ed25519" "$ADMIN_HOME/.ssh/id_ed25519"
  echo "bootstrap-ops: skopiowano klucz prywatny labu"
fi

# 5. Profil admin: konfiguracja Ansible z repo i start w katalogu repo
PROFILE="$ADMIN_HOME/.profile"
touch "$PROFILE"
chown "$ADMIN_USER:$ADMIN_USER" "$PROFILE"
grep -qxF "export ANSIBLE_CONFIG=$REPO/ansible.cfg" "$PROFILE" \
  || echo "export ANSIBLE_CONFIG=$REPO/ansible.cfg" >> "$PROFILE"
# Hasło do Ansible Vault z pliku poza Gitem (etap 2, R7) — zmienna, nie ansible.cfg, żeby lint w CI
# nie wymagał hasła; brak pliku kończy przebieg błędem w playbooks/preflight.yml
grep -qxF "export ANSIBLE_VAULT_PASSWORD_FILE=$REPO/.vault_pass" "$PROFILE" \
  || echo "export ANSIBLE_VAULT_PASSWORD_FILE=$REPO/.vault_pass" >> "$PROFILE"
grep -qxF "cd $REPO" "$PROFILE" || echo "cd $REPO" >> "$PROFILE"
