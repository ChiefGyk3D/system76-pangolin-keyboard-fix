#!/bin/bash
# install.sh
# Installs System76 drivers and tools on Debian-based distros (Parrot, Ubuntu, etc.)
# for the System76 Pangolin (pang11) laptop.
#
# This installs:
#   1. system76-dkms      - Kernel driver for keyboard backlight, hotkeys, etc.
#   2. system76-power      - Power management daemon (brightness, profiles)
#   3. keyboard-configurator - GUI app to configure keyboard backlight colors
#   4. Keyboard resume fix  - Fixes keyboard not responding after suspend
#
# Run with: sudo bash install.sh

set -e

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (sudo)."
    echo "Usage: sudo bash install.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="/tmp/pangolin-keyboard-build"

echo "============================================"
echo " System76 Pangolin (pang11) Setup"
echo " For Debian-based distros (Parrot, etc.)"
echo "============================================"
echo ""

# --- Step 1: Install dependencies ---
echo "[1/6] Installing build dependencies..."
apt-get update -qq
apt-get install -y \
    dkms \
    git \
    build-essential \
    linux-headers-$(uname -r) \
    cargo \
    rustc \
    libgtk-3-dev \
    libpango1.0-dev \
    libcairo2-dev \
    libglib2.0-dev \
    libatk1.0-dev \
    libhidapi-dev \
    pkg-config \
    2>&1 | tail -5
echo "   -> Dependencies installed."

# --- Step 2: Build and install system76-dkms ---
echo ""
echo "[2/6] Installing system76-dkms kernel driver..."
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

if [[ -d system76-dkms ]]; then
    cd system76-dkms && git pull --quiet
else
    git clone --quiet https://github.com/pop-os/system76-dkms.git
    cd system76-dkms
fi

VER=$(head -1 debian/changelog | grep -oP '\(([^)]+)\)' | tr -d '()' | cut -d- -f1)
echo "   Driver version: $VER"

# Remove old DKMS versions if present
dkms remove system76/$VER --all 2>/dev/null || true

# Set up DKMS source
rm -rf /usr/src/system76-$VER
mkdir -p /usr/src/system76-$VER/src
cp Makefile Kbuild /usr/src/system76-$VER/
cp src/*.c src/Kbuild /usr/src/system76-$VER/src/

cat > /usr/src/system76-$VER/dkms.conf << DKMSEOF
PACKAGE_NAME="system76"
PACKAGE_VERSION="$VER"
MAKE="make -C \${kernel_source_dir} M=\${dkms_tree}/\${PACKAGE_NAME}/\${PACKAGE_VERSION}/build modules"
CLEAN="make -C \${kernel_source_dir} M=\${dkms_tree}/\${PACKAGE_NAME}/\${PACKAGE_VERSION}/build clean"
BUILT_MODULE_NAME="system76"
BUILT_MODULE_LOCATION="src"
DEST_MODULE_LOCATION="/kernel/drivers/platform/x86"
AUTOINSTALL="yes"
DKMSEOF

dkms add system76/$VER
dkms build system76/$VER
dkms install system76/$VER
echo "   -> system76-dkms installed."

# Blacklist the in-tree system76_acpi (doesn't handle keyboard backlight)
# and ensure system76 loads at boot
echo "system76" > /etc/modules-load.d/system76.conf
echo "blacklist system76_acpi" > /etc/modprobe.d/system76.conf

# Load the driver now
rmmod system76_acpi 2>/dev/null || true
modprobe system76 2>/dev/null || true
echo "   -> Driver loaded and configured for boot."

# --- Step 3: Build and install system76-power ---
echo ""
echo "[3/6] Building and installing system76-power..."
cd "$BUILD_DIR"

if [[ -d system76-power ]]; then
    cd system76-power && git pull --quiet
else
    git clone --quiet https://github.com/pop-os/system76-power.git
    cd system76-power
fi

# Build as the calling user (not root) if possible, to avoid cargo permission issues
SUDO_USER_HOME=$(eval echo "~${SUDO_USER:-root}")
export CARGO_HOME="${SUDO_USER_HOME}/.cargo"
make 2>&1 | tail -3
make install
echo "   -> system76-power installed."

# Enable and start the daemon
systemctl daemon-reload
systemctl enable --now com.system76.PowerDaemon.service 2>/dev/null || true
echo "   -> system76-power daemon enabled and running."

# --- Step 4: Build and install keyboard-configurator ---
echo ""
echo "[4/6] Building and installing keyboard-configurator..."
cd "$BUILD_DIR"

if [[ -d keyboard-configurator ]]; then
    cd keyboard-configurator && git pull --quiet
else
    git clone --quiet https://github.com/pop-os/keyboard-configurator.git
    cd keyboard-configurator
fi

make 2>&1 | tail -3
make install
echo "   -> keyboard-configurator installed."

# --- Step 5: Keyboard resume fix ---
echo ""
echo "[5/6] Installing keyboard resume fix..."

cat > /etc/systemd/system/fix-keyboard-resume.service << 'EOF'
[Unit]
Description=Reset i8042 keyboard controller after suspend/resume
After=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo "i8042" > /sys/bus/platform/drivers/i8042/unbind; sleep 1; echo "i8042" > /sys/bus/platform/drivers/i8042/bind'

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
EOF

systemctl daemon-reload
systemctl enable fix-keyboard-resume.service
echo "   -> Keyboard resume fix installed."

# Add i8042.reset kernel parameter
GRUB_FILE="/etc/default/grub"
if [[ -f "$GRUB_FILE" ]]; then
    if ! grep -q "i8042.reset=1" "$GRUB_FILE"; then
        cp "$GRUB_FILE" "${GRUB_FILE}.bak.$(date +%Y%m%d%H%M%S)"
        sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)/\1 i8042.reset=1/' "$GRUB_FILE"
        update-grub 2>/dev/null || grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
        echo "   -> Added i8042.reset=1 kernel parameter."
    else
        echo "   -> i8042.reset=1 already present."
    fi
fi

# --- Step 6: Verify ---
echo ""
echo "[6/6] Verifying installation..."
echo ""

if lsmod | grep -q "^system76 "; then
    echo "   [OK] system76 kernel module loaded"
else
    echo "   [!!] system76 kernel module not loaded (may need reboot)"
fi

if [[ -d /sys/class/leds/system76::kbd_backlight ]]; then
    BRIGHTNESS=$(cat /sys/class/leds/system76::kbd_backlight/brightness)
    MAX=$(cat /sys/class/leds/system76::kbd_backlight/max_brightness)
    echo "   [OK] Keyboard backlight detected (brightness: $BRIGHTNESS/$MAX)"
else
    echo "   [!!] Keyboard backlight not detected (may need reboot)"
fi

if systemctl is-active --quiet com.system76.PowerDaemon.service; then
    echo "   [OK] system76-power daemon running"
else
    echo "   [!!] system76-power daemon not running"
fi

if which system76-keyboard-configurator >/dev/null 2>&1; then
    echo "   [OK] keyboard-configurator installed"
else
    echo "   [!!] keyboard-configurator not found"
fi

echo ""
echo "============================================"
echo " Installation complete!"
echo "============================================"
echo ""
echo "You can now:"
echo "  - Change keyboard colors:  system76-keyboard-configurator"
echo "  - Check power profile:     system76-power profile"
echo "  - Set color via CLI:       echo 'ff0000' | sudo tee /sys/class/leds/system76::kbd_backlight/color_{left,center,right,extra}"
echo "  - Set brightness via CLI:  echo 128 | sudo tee /sys/class/leds/system76::kbd_backlight/brightness"
echo ""
echo "A reboot is recommended to ensure all changes take effect."
