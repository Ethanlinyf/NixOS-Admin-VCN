#!/usr/bin/env bash
set -e

# === Environment detection (Jetson / non-NixOS support) ===
if grep -q "NixOS" /etc/os-release 2>/dev/null || [ -f /etc/nixos/configuration.nix ]; then
  IS_NIXOS=true
else
  IS_NIXOS=false
fi
IS_JETSON=false
if [ -f /etc/nv_tegra_release ]; then
  IS_JETSON=true
  echo "Detected Jetson (stock JetPack Ubuntu)"
fi

nix --extra-experimental-features 'nix-command flakes' run nixpkgs#dialog -- --title "CQUniAI NixOS Installer" --msgbox "Ethernet connected?\nPress OK when ready." 8 40

# === Load previous deployment configuration (re-deploy) ===
CLONE_DIR="/etc/nixdeploy"
SECRETS_DIR="$CLONE_DIR/secrets"
IS_REDEPLOY=false
HAS_DUCKDNS_SECRETS=false
HAS_VNC_PASSWD=false
HAS_MONGODB_PASS=false
HAS_SSH_AUTHORIZED_KEY=false

if [ -d "$CLONE_DIR" ]; then
  IS_REDEPLOY=true
  echo "→ Previous deployment detected at $CLONE_DIR"
  # secrets/ is mode 700 root-owned — must use sudo to test file existence
  if sudo test -f "$SECRETS_DIR/duckdns-subdomain" && sudo test -f "$SECRETS_DIR/duckdns-token"; then
    HAS_DUCKDNS_SECRETS=true
  fi
  sudo test -f /root/.vnc/passwd && HAS_VNC_PASSWD=true
  sudo test -f "$SECRETS_DIR/mongodb-root-password" && HAS_MONGODB_PASS=true
  sudo test -f "$SECRETS_DIR/ssh-authorized-key" && HAS_SSH_AUTHORIZED_KEY=true
fi

# Host selection — on re-deploy use the machine's current hostname
HOSTS=$(ls /tmp/nixdeploy/hosts/ 2>/dev/null | tr '\n' ' ')
if [ -z "$HOSTS" ]; then
  nix --extra-experimental-features 'nix-command flakes' run nixpkgs#dialog -- --msgbox "No hosts found. Using default." 8 40
  HOSTNAME="default"
elif [ "$IS_REDEPLOY" = true ]; then
  HOSTNAME=$(hostname -s 2>/dev/null || cat /etc/hostname 2>/dev/null || true)
  HOSTNAME=$(echo "$HOSTNAME" | tr -d '[:space:]')
  echo "→ Using current hostname: $HOSTNAME"
else
  MENU=""
  i=1
  for h in $HOSTS; do
    MENU="$MENU $i $h"
    i=$((i+1))
  done
  SELECTED=$(nix --extra-experimental-features 'nix-command flakes' run nixpkgs#dialog -- --stdout --menu "Select hostname/configuration:" 15 50 10 $MENU)
  HOSTNAME=$(echo $HOSTS | awk "{print \$$SELECTED}")
fi

# DuckDNS — reuse stored secrets on re-deploy, otherwise prompt
clear
echo "Installing for [${HOSTNAME}]"
echo "============================"
echo ""

if [ "$HAS_DUCKDNS_SECRETS" = true ]; then
  echo "→ Reusing existing DuckDNS configuration"
else
  DUCKDNS_DEFAULT="${HOSTNAME}cqu"
  echo -n "DuckDNS subdomain [$DUCKDNS_DEFAULT]: "
  read -e -r DUCKDNS_SUB
  DUCKDNS_SUB=${DUCKDNS_SUB:-$DUCKDNS_DEFAULT}
  echo ""
  echo -n "DuckDNS token: "
  read -e -r DUCKDNS_TOKEN
fi

# SSH public key for pi user (all hosts): capture at install.sh rather than per-host hardcoded.
# Replicates bitdeploy handling (friday as clean reference host using module + secret).
# Early so migration from existing authorized_keys works and secrets/ is populated before source mv.
if [ "$HAS_SSH_AUTHORIZED_KEY" = true ]; then
  SSH_PUBLIC_KEY=$(sudo cat "$SECRETS_DIR/ssh-authorized-key" 2>/dev/null || true)
  echo " Reusing existing SSH authorized key"
  sudo install -d -m 700 -o root -g root /etc/nixdeploy/secrets 2>/dev/null || true
  sudo install -m 600 /dev/stdin /etc/nixdeploy/secrets/ssh-authorized-key <<< "$SSH_PUBLIC_KEY" || true
elif [ "$IS_NIXOS" = true ] && sudo test -s /home/pi/.ssh/authorized_keys 2>/dev/null; then
  echo " Migrating SSH key from existing authorized_keys"
  sudo install -d -m 700 -o root -g root /etc/nixdeploy/secrets 2>/dev/null || true
  sudo cp /home/pi/.ssh/authorized_keys /etc/nixdeploy/secrets/ssh-authorized-key
  sudo chmod 600 /etc/nixdeploy/secrets/ssh-authorized-key
  SSH_PUBLIC_KEY=$(sudo cat /etc/nixdeploy/secrets/ssh-authorized-key)
  HAS_SSH_AUTHORIZED_KEY=true
else
  echo ""
  echo "SSH public key for user 'pi' (single line, starts with ssh-rsa / ssh-ed25519 / etc.):"
  read -e -r SSH_PUBLIC_KEY
  if [ -n "$SSH_PUBLIC_KEY" ]; then
    sudo install -d -m 700 -o root -g root /etc/nixdeploy/secrets 2>/dev/null || true
    sudo install -m 600 /dev/stdin /etc/nixdeploy/secrets/ssh-authorized-key <<< "$SSH_PUBLIC_KEY"
    HAS_SSH_AUTHORIZED_KEY=true
  fi
fi

# clear the screen so the passwords don't linger on the display
clear

# NVIDIA detection (for logging only)
NVIDIA=0
if nix --extra-experimental-features 'nix-command flakes' run nixpkgs#pciutils | grep -Ei 'nvidia' >/dev/null; then NVIDIA=1; fi

echo "→ Installing for host: $HOSTNAME (NVIDIA detected: $NVIDIA)"

# Copy hardware config FIRST (while still in /tmp)
echo "→ Copying hardware configuration from initial NixOS install..."
sudo cp /etc/nixos/hardware-configuration.nix "/tmp/nixdeploy/hosts/$HOSTNAME/hardware-configuration.nix" 2>/dev/null || true

# Move repo permanently (preserve any existing secrets)
echo "→ Moving repo to permanent location $CLONE_DIR..."
sudo mkdir -p "$CLONE_DIR"

# Backup existing secrets if present (mosquitto password, future secrets, etc.)
if [ -d "$CLONE_DIR/secrets" ]; then
  echo "→ Preserving existing secrets directory..."
  sudo mv "$CLONE_DIR/secrets" "/tmp/nixdeploy-secrets-backup-$$"
fi

sudo rm -rf "$CLONE_DIR"
sudo mv /tmp/nixdeploy "$CLONE_DIR"

# Restore secrets after the fresh clone is in place
if [ -d "/tmp/nixdeploy-secrets-backup-$$" ]; then
  sudo mv "/tmp/nixdeploy-secrets-backup-$$" "$CLONE_DIR/secrets"
  echo "→ Secrets directory restored."
fi

# Create VNC password file (NixOS only)
if [ "$IS_NIXOS" = true ]; then
  if [ "$HAS_VNC_PASSWD" = true ]; then
    echo "→ Reusing existing VNC password"
  else
    echo -n "VNC password: "
    read -e -r VNC_PASS
    echo " Creating VNC password file..."
    sudo mkdir -p /root/.vnc
    echo "$VNC_PASS" | sudo nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#tigervnc --command vncpasswd -f | sudo tee /root/.vnc/passwd > /dev/null
    sudo chmod 600 /root/.vnc/passwd
    clear
  fi
fi

# MongoDB root password (tars only — captured during initial install so it can be used by initialRootPasswordFile + postStart)
if [ "$IS_NIXOS" = true ] && [ "$HOSTNAME" = "tars" ]; then
  if [ "$HAS_MONGODB_PASS" = true ]; then
    echo "→ Reusing existing MongoDB root password"
  else
    echo -n "MongoDB root password (for authenticated remote access via tarscqu.duckdns.org): "
    read -e -r MONGODB_ROOT_PASS
    echo " Storing MongoDB root password in secrets..."
    sudo mkdir -p /etc/nixdeploy/secrets
    sudo install -m 600 /dev/stdin /etc/nixdeploy/secrets/mongodb-root-password <<< "$MONGODB_ROOT_PASS"
    clear
  fi
fi

# Create secrets (skip DuckDNS on re-deploy — preserved via secrets backup)
if [ "$HAS_DUCKDNS_SECRETS" = true ]; then
  echo "→ DuckDNS secrets unchanged"
else
  echo "→ Creating DuckDNS secrets..."
  sudo mkdir -p /etc/nixdeploy/secrets
  sudo install -m 600 /dev/stdin /etc/nixdeploy/secrets/duckdns-subdomain <<< "$DUCKDNS_SUB"
  sudo install -m 600 /dev/stdin /etc/nixdeploy/secrets/duckdns-token <<< "$DUCKDNS_TOKEN"
fi

# Ensure SSH authorized key secret is present (early capture or reuse; idempotent re-apply)
if [ -n "${SSH_PUBLIC_KEY:-}" ]; then
  sudo install -m 600 /dev/stdin /etc/nixdeploy/secrets/ssh-authorized-key <<< "$SSH_PUBLIC_KEY" || true
fi
sudo mkdir -p /etc/nixdeploy/secrets
sudo chmod 700 /etc/nixdeploy/secrets

# Generate .gitignore
echo "→ Generating .gitignore..."
cat > /tmp/.gitignore << 'EOG'
# Dynamic/machine-specific files (never commit)
hosts/*/hardware-configuration.nix

# Secrets
secrets/

# Nix build artifacts
result*
*.nix~
*.log
EOG
sudo mv /tmp/.gitignore "$CLONE_DIR/.gitignore"

cd "$CLONE_DIR"

if [ "$IS_NIXOS" = true ]; then
  echo "→ Deploying full NixOS configuration (this may take a few minutes)..."
  sudo nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#git --command nixos-rebuild boot --cores 0 --impure --flake "path:$CLONE_DIR#$HOSTNAME"
else
  # common to non-nixos
  echo "→ Non-NixOS deployment for $HOSTNAME (preserving vendor NVIDIA/CUDA stack)..."

  # Set the hostname to match the selected configuration (currently "ubuntu" on stock JetPack)
  echo " Setting hostname to $HOSTNAME..."
  sudo hostnamectl set-hostname "$HOSTNAME"
  if grep -q '^127.0.1.1' /etc/hosts; then
    sudo sed -i "s/^127.0.1.1.*/127.0.1.1\t$HOSTNAME/" /etc/hosts
  else
    echo "127.0.1.1\t$HOSTNAME" | sudo tee -a /etc/hosts >/dev/null
  fi

  # Install Determinate Nix
  if ! command -v nix >/dev/null 2>&1; then
    echo " Installing Determinate Nix..."
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh || true
  fi

  sudo apt-get update
  sudo apt-get install -y curl git zstd xfce4 xfce4-goodies lightdm x11vnc openssh-server iproute2 nano vim firefox tigervnc-viewer

  # Stop WiFi from sleeping, prevent remote access becoming unavailable
  echo " Disabling WiFi power saving for stable always-on operation..."
  sudo mkdir -p /etc/NetworkManager/conf.d
  sudo tee /etc/NetworkManager/conf.d/00-disable-wifi-powersave.conf >/dev/null << 'EOC'
[connection]
wifi.powersave = 2
EOC

  # write ssh public key to authorized_keys from captured secret (no longer per-host hardcoded in install.sh)
  echo "→ Setting up SSH key for pi and hardening sshd..."
  if sudo test -f /etc/nixdeploy/secrets/ssh-authorized-key 2>/dev/null; then
    sudo mkdir -p /home/pi/.ssh
    sudo cp /etc/nixdeploy/secrets/ssh-authorized-key /home/pi/.ssh/authorized_keys
    sudo chown -R pi:pi /home/pi/.ssh
    sudo chmod 700 /home/pi/.ssh
    sudo chmod 600 /home/pi/.ssh/authorized_keys
    echo " SSH public key from secret installed for pi user."
  else
    echo "WARNING: /etc/nixdeploy/secrets/ssh-authorized-key not found. Key-based SSH login not configured."
  fi

  sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

  # set lightdm as default display manager (for VNC and GUI)
  echo "/usr/sbin/lightdm" | sudo tee /etc/X11/default-display-manager >/dev/null

  # VNC password (simple interactive method that works on Jetson)
  if [ "$HAS_VNC_PASSWD" = true ]; then
    echo "→ Reusing existing VNC password"
  else
    echo " Creating VNC password file..."
    sudo mkdir -p /root/.vnc
    sudo x11vnc -storepasswd /root/.vnc/passwd
    sudo chmod 600 /root/.vnc/passwd
  fi

  if [ "$IS_JETSON" = true ]; then
    echo " NVidia Jetson specific setup..."

    # Native Ollama (Jetson-optimised, CUDA enabled)
    curl -fsSL https://ollama.com/install.sh | sh

    # Pull the model declared in the host's configuration.nix (keeps hybrid in sync)
    case "$HOSTNAME" in
      orin)
        MODEL="qwen3.6:27b"
        ;;
      xavier)
        MODEL="qwen3.5:9b"
        ;;
      *)
        MODEL="qwen3.5:9b"
        ;;
    esac
    echo " Pulling $MODEL for $HOSTNAME (large download – monitor with 'ollama ps' or 'ollama list')"
    sleep 8
    ollama pull "$MODEL" || echo "Pull may need manual retry; check exact tag with 'ollama search qwen'"

    # Ollama keep-alive + reliable preload after boot (works on Jetson)
    echo " Configuring Ollama keep-alive + preload at boot for $MODEL"
    sudo mkdir -p /etc/systemd/system/ollama.service.d
    sudo tee /etc/systemd/system/ollama.service.d/keepalive.conf >/dev/null << EOF
[Service]
Environment=OLLAMA_KEEP_ALIVE=-1
ExecStartPost=/bin/sh -c 'sleep 5; /usr/local/bin/ollama run $MODEL "" > /dev/null 2>&1 &'
EOF
    sudo systemctl daemon-reload
    sudo systemctl restart ollama
    echo " Ollama configured. Model will preload after boot."
  fi
  # continue with non-nixos setup
  echo " Continue Non-NixOS deployment for $HOSTNAME..."

  # Deploy shared services (single source of truth from modules/ - .service files are the standard deployment format for non-NixOS)
  sudo cp modules/x11vnc.service modules/duckdns-update.service modules/duckdns-update.timer /etc/systemd/system/
  sudo chmod +x /etc/nixdeploy/modules/duckdns-local-ip-update.sh
  sudo systemctl daemon-reload
  sudo systemctl enable --now x11vnc duckdns-update.timer ssh || true
fi

echo ""
echo "========================================"
echo "Setup complete! Config is now permanently in $CLONE_DIR"
echo "Rebooting in 5 seconds"
echo "========================================"

sleep 5
sudo reboot
