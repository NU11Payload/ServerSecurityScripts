#/bin/bash

set -e 
 
# Check if script is run as root
# You need root privileges to modify system security settings
# Other users will not be able to run this script successfully
# This script will try to make the system more secure
# If you find this useful, please consider supporting me on github - 0xEALANA

log() {
  echo -e "[$(date +"%Y-%m-%d %H:%M:%S")] $1"
}

if [[ $EUID -ne 0 ]]; then
  log "This script must be run as root" 
  exit 1
fi
OS=$(uname -s | tr A-Z a-z)

case $OS in
  linux)
    source /etc/os-release
    case $ID in
      debian|ubuntu|mint)
        log "Detected $OS"

        # apt update
        ;;

      fedora|rhel|centos)
        log "Detected $OS"
        # dnf update or yum update
        dnf update || yum update
        ;;

      *)
        # echo -n "unsupported linux distro"
        ;;
    esac
  ;;

  darwin)
    log "Detected $OS"
    # brew update
    ;;

  *)
    log "Unsupported OS"
    ;;
esac

if [ "$OS" = "linux" ] && [ -f /etc/os-release ]; then
  . /etc/os-release
  DISTRO_ID="$ID"
else
  DISTRO_ID="$OS"
fi

log "Detected OS: $OS"
log "Detected Distribution ID: $DISTRO_ID"

package_name=(
  "vim"
  "curl"
  "wget"
  "git"
  "fail2ban"
)

if [ "$OS" = "Linux" ]; then
  case $DISTRO_ID in
    debian|ubuntu|mint)
      log "Detected $DISTRO_ID"
      ;;
    fedora|rhel|centos|almalinux)
      log "Detected $DISTRO_ID"
      ;;
    arch)
      log "Detected $DISTRO_ID"
      ;;
    *)
      log "Unsupported Linux distribution"
      ;;
  esac
fi

install_package() {
local package="$1"
  log "Installing and attempting to install $package"

  case "$DISTRO_ID" in
    debian|ubuntu|mint)
      apt-get update && apt-get install -y "$package"
      apt_status=$?
      ;;
    fedora|rhel|centos|almalinux)
      dnf install -y "$package" || yum install -y "$package"
      dnf_status=$?
      ;;
    arch)
      pacman -Syu --noconfirm "$package"
      pacman_status=$?
      ;;
    *)
      log "Unsupported Linux distribution for package installation"
      return 1
      ;;
  esac

  if [ "$apt_status" -eq 0 ] || [ "$dnf_status" -eq 0 ] || [ "$pacman_status" -eq 0 ]; then
    log "Package '$package' installed successfully."
    return 0
  else
    log "Failed to install package '$package'."
    return 1
  fi
}

wait
#Plan to add input to add ssh key from user input, as well, I locked my self out of my server testing
log "Configuring SSH..."
ssh_config="/etc/ssh/sshd_config"

sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' "$ssh_config"

# Disable password authentication
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' "$ssh_config"

# Disable X11 forwarding
sed -i 's/^#\?X11Forwarding.*/X11Forwarding no/' "$ssh_config"

# Set maximum authentication tries
sed -i 's/^#\?MaxAuthTries.*/MaxAuthTries 3/' "$ssh_config"

# Disable TCP forwarding
sed -i 's/^#\?AllowTcpForwarding.*/AllowTcpForwarding no/' "$ssh_config"

# Restart SSH service 
if systemctl restart ssh; then
  log "SSH service restarted successfully."
elif systemctl restart sshd; then
  log "SSHd service restarted successfully."
else
  log "Failed to restart SSH service."
fi

log "SSH configuration updated successfully."

log "Installing packages..."
for package in "${package_name[@]}"; do
  if install_package "$package"; then
    log "Package '$package' installed successfully."
  else
    log "Package '$package' failed to install."
  fi
done
