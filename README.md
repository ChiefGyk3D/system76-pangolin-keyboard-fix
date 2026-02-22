# Pangolin Keyboard Resume Fix

Fixes the keyboard becoming unresponsive after suspend/resume on the **System76 Pangolin (pang11)** laptop.

## The Problem

After waking the Pangolin from suspend (sleep), the built-in keyboard stops responding entirely. The only way to recover is a hard power-off via the power button. This is caused by the `i8042` PS/2 keyboard controller failing to reinitialize after S3 (deep) sleep.

This is a known issue affecting AMD-based System76 laptops running Linux.

## What This Fix Does

The script installs two complementary fixes:

1. **Systemd resume service** — Automatically unbinds and rebinds the `i8042` driver every time the system wakes from suspend, forcing the keyboard controller to reinitialize.

2. **Kernel parameter (`i8042.reset=1`)** — Tells the kernel to reset the i8042 controller during the resume process at a lower level. Added to GRUB config automatically.

3. **Optional: Switch to `s2idle`** — The script offers to change the default sleep mode from `deep` (S3) to `s2idle` (modern standby), which avoids the issue entirely at the cost of slightly higher power consumption during sleep.

## Requirements

- System76 Pangolin (pang11) or similar laptop with an i8042 keyboard controller
- Linux with systemd
- GRUB bootloader (for the kernel parameter fix)
- Root access

## Installation

```bash
git clone https://github.com/YOUR_USERNAME/pangolin-keyboard-fix.git
cd pangolin-keyboard-fix
sudo bash fix-keyboard-resume.sh
```

The systemd service takes effect immediately on the next suspend/resume cycle. The kernel parameter requires a reboot.

## Manual Quick Test

If your keyboard is currently frozen after a resume, you can recover it from an SSH session or a virtual console (`Ctrl+Alt+F2`, if it responds):

```bash
sudo bash -c 'echo "i8042" > /sys/bus/platform/drivers/i8042/unbind; sleep 1; echo "i8042" > /sys/bus/platform/drivers/i8042/bind'
```

## Uninstall

```bash
sudo systemctl disable --now fix-keyboard-resume.service
sudo rm /etc/systemd/system/fix-keyboard-resume.service
sudo rm -f /etc/systemd/sleep.conf.d/s2idle.conf
```

Then edit `/etc/default/grub` and remove `i8042.reset=1` (and `mem_sleep_default=s2idle` if added), then run:

```bash
sudo update-grub
```

## Tested On

- System76 Pangolin (pang11)
- Parrot Security 7.1 / Debian-based
- Kernel 6.17.x

Should also work on other Linux distributions with systemd and GRUB on similar hardware.

## License

MIT
