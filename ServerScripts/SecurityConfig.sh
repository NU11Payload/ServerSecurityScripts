#/bin/bash

set -e 
 
# Check if script is run as root
# You need root privileges to modify system security settings
# Other users will not be able to run this script successfully
# This script will try to make the system more secure
# If you find this useful, please consider supporting me on github - 0xEALANA

# Function to log messages with timestamp
log() {
  echo -e "[$(date +"%Y-%m-%d %H:%M:%S")] $1"
}

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
  log "This script must be run as root" 
  exit 1
fi

# Determine the operating system
OS=$(uname -s | tr A-Z a-z)

# Handle different operating systems
case $OS in
  linux)
    # Source the os-release file to get distribution information
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
    esac echo $?
  ;;

  darwin)
    log "Detected $OS"
    # brew update
    ;;

  *)
    log "Unsupported OS"
    ;;
esac

# Determine the Linux distribution ID
if [ "$OS" = "linux" ] && [ -f /etc/os-release ]; then
  # Source the os-release file to get variables
  . /etc/os-release
  DISTRO_ID="$ID"
else
  # For non-Linux or systems without os-release
  DISTRO_ID="$OS"
fi

log "Detected OS: $OS"
log "Detected Distribution ID: $DISTRO_ID"

# Define the list of packages to install
package_name=(
  "vim"
  "curl"
  "wget"
  "git"
  "fail2ban"
)

# Handle package installation based on the distribution ID
if [ "$OS" = "Linux" ]; then
  case $DISTRO_ID in
    debian|ubuntu|mint)
      # Debian-based
      log "Detected $DISTRO_ID"
      ;;
    fedora|rhel|centos)
      # Red Hat-based
      log "Detected $DISTRO_ID"
      ;;
    arch)
      # Arch-based
      log "Detected $DISTRO_ID"
      ;;
    *)
      log "Unsupported Linux distribution"
      ;;
  esac
fi

# Function to install a package
install_package() {
  local package="$1"
  log "Installing and attempting to install $package"

    case "$DISTRO_ID" in
        debian|ubuntu|mint)
            apt-get update && apt-get install -y "$package"
            apt_status=$?
            ;;
        fedora|rhel|centos)
            dnf install -y "$package" || yum install -y "$package"
            dnf_status=$?
            ;;
        arch)
            pacman -Syu --noconfirm "$package"
            pacman_status=$?
            ;;
        *)
            log "Unsupported Linux distribution for package installation"
            exit 1
            ;;
    esac
    if [ "$apt_status" -eq 0 ] || [ "$dnf_status" -eq 0 ] || [ "$pacman_status" -eq 0 ]; then
        log "Package '$package' installed successfully."
    else
        log "Failed to install package '$package'."
        exit 1
    fi
}

wait

# Configure SSH
log "Configuring SSH..."
ssh_config="/etc/ssh/sshd_config"

# Disable root login
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
systemctl restart ssh || systemctl restart sshd

log "SSH configuration updated successfully."

# Install security packages
log "Installing security packages..."
for package in "${package_name[@]}"; do
  install_package "$package"
done
