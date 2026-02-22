#!/bin/bash
# fix-keyboard-resume.sh
# Fixes System76 Pangolin (pang11) keyboard not responding after suspend/resume
# The i8042 PS/2 keyboard controller fails to reinitialize after S3 deep sleep.
#
# This script installs two fixes:
#   1. A systemd service that unbinds/rebinds the i8042 driver on resume
#   2. A kernel parameter (i8042.reset=1) to force controller reset on resume
#
# Run with: sudo bash fix-keyboard-resume.sh

set -e

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (sudo)."
    exit 1
fi

echo "=== System76 Pangolin Keyboard Resume Fix ==="
echo ""

# --- Fix 1: systemd resume service ---
echo "[1/3] Creating systemd resume service for i8042 keyboard reset..."

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
echo "   -> Service installed and enabled."

# --- Fix 2: Kernel parameter i8042.reset=1 ---
echo ""
echo "[2/3] Adding i8042.reset=1 kernel parameter..."

GRUB_FILE="/etc/default/grub"
if [[ -f "$GRUB_FILE" ]]; then
    # Check if already present
    if grep -q "i8042.reset=1" "$GRUB_FILE"; then
        echo "   -> i8042.reset=1 already present in GRUB config."
    else
        # Backup grub config
        cp "$GRUB_FILE" "${GRUB_FILE}.bak.$(date +%Y%m%d%H%M%S)"
        # Append to GRUB_CMDLINE_LINUX_DEFAULT
        sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)/\1 i8042.reset=1/' "$GRUB_FILE"
        echo "   -> Added i8042.reset=1 to GRUB_CMDLINE_LINUX_DEFAULT."
        echo "   -> Updating GRUB..."
        update-grub 2>/dev/null || grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || echo "   !! Could not update grub automatically. Run 'sudo update-grub' manually."
    fi
else
    echo "   -> /etc/default/grub not found. You may need to add 'i8042.reset=1' to your bootloader config manually."
fi

# --- Optional: Switch to s2idle ---
echo ""
echo "[3/3] Sleep mode configuration..."
echo "   Current sleep mode: $(cat /sys/power/mem_sleep)"
echo ""
echo "   Your system is using 'deep' (S3) sleep. Switching to 's2idle' can also"
echo "   help avoid this issue (modern standby, slightly higher power use in sleep)."
echo ""
read -p "   Switch default sleep mode to s2idle? [y/N]: " SWITCH_SLEEP

if [[ "$SWITCH_SLEEP" =~ ^[Yy]$ ]]; then
    # Create systemd sleep.conf drop-in
    mkdir -p /etc/systemd/sleep.conf.d
    cat > /etc/systemd/sleep.conf.d/s2idle.conf << 'EOF'
[Sleep]
MemorySleepMode=s2idle
EOF
    # Also set via kernel param for immediate effect on next boot
    if [[ -f "$GRUB_FILE" ]] && ! grep -q "mem_sleep_default=s2idle" "$GRUB_FILE"; then
        sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)/\1 mem_sleep_default=s2idle/' "$GRUB_FILE"
        update-grub 2>/dev/null || grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
    fi
    echo "   -> Sleep mode will default to s2idle after next reboot."
else
    echo "   -> Keeping deep (S3) sleep mode."
fi

echo ""
echo "=== Done! ==="
echo ""
echo "The systemd service fix takes effect immediately on next suspend/resume."
echo "The kernel parameter fix requires a reboot."
echo ""
echo "To test now without rebooting, you can suspend and resume your laptop."
echo "If the keyboard still doesn't work, reboot once for the kernel parameter to take effect."
echo ""
echo "To revert these changes:"
echo "  sudo systemctl disable --now fix-keyboard-resume.service"
echo "  sudo rm /etc/systemd/system/fix-keyboard-resume.service"
echo "  sudo rm -f /etc/systemd/sleep.conf.d/s2idle.conf"
echo "  Edit /etc/default/grub and remove 'i8042.reset=1' and 'mem_sleep_default=s2idle'"
echo "  sudo update-grub"
