#!/bin/bash
# uninstall.sh
# Removes all System76 drivers and tools installed by install.sh

set -e

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (sudo)."
    exit 1
fi

echo "=== Uninstalling System76 Pangolin tools ==="
echo ""

# Remove keyboard resume fix
echo "[1/4] Removing keyboard resume fix..."
systemctl disable --now fix-keyboard-resume.service 2>/dev/null || true
rm -f /etc/systemd/system/fix-keyboard-resume.service
rm -f /etc/systemd/sleep.conf.d/s2idle.conf

GRUB_FILE="/etc/default/grub"
if [[ -f "$GRUB_FILE" ]]; then
    sed -i 's/ i8042.reset=1//g' "$GRUB_FILE"
    sed -i 's/ mem_sleep_default=s2idle//g' "$GRUB_FILE"
    update-grub 2>/dev/null || grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
fi
echo "   -> Done."

# Remove system76-power
echo "[2/4] Removing system76-power..."
systemctl disable --now com.system76.PowerDaemon.service 2>/dev/null || true
rm -f /usr/bin/system76-power
rm -f /usr/lib/systemd/system/com.system76.PowerDaemon.service
rm -f /usr/share/dbus-1/system.d/com.system76.PowerDaemon.conf
rm -f /usr/share/dbus-1/interfaces/com.system76.PowerDaemon.xml
rm -f /usr/share/polkit-1/actions/com.system76.PowerDaemon.policy
systemctl daemon-reload
echo "   -> Done."

# Remove keyboard-configurator
echo "[3/4] Removing keyboard-configurator..."
rm -f /usr/local/bin/system76-keyboard-configurator
rm -f /usr/local/lib/libsystem76_keyboard_configurator.so
rm -f /usr/local/lib/pkgconfig/system76_keyboard_configurator.pc
rm -f /usr/local/include/system76_keyboard_configurator.h
rm -f /usr/local/share/applications/com.system76.keyboardconfigurator.desktop
rm -f /usr/local/share/metainfo/com.system76.keyboardconfigurator.appdata.xml
rm -f /usr/local/share/icons/hicolor/scalable/apps/com.system76.keyboardconfigurator.svg
echo "   -> Done."

# Remove system76-dkms
echo "[4/4] Removing system76-dkms..."
VER=$(dkms status system76 2>/dev/null | head -1 | grep -oP '[\d.]+' | head -1)
if [[ -n "$VER" ]]; then
    dkms remove system76/$VER --all 2>/dev/null || true
    rm -rf /usr/src/system76-$VER
fi
rm -f /etc/modules-load.d/system76.conf
rm -f /etc/modprobe.d/system76.conf
rmmod system76 2>/dev/null || true
echo "   -> Done."

# Clean up build directory
rm -rf /tmp/pangolin-keyboard-build

echo ""
echo "=== Uninstall complete ==="
echo "A reboot is recommended."
