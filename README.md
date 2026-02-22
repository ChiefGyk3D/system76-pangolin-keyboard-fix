# Pangolin Keyboard Fix

Installs System76 drivers and tools on **non-Pop!_OS** Debian-based distros (Parrot Security, Ubuntu, Debian, etc.) for the **System76 Pangolin (pang11)** laptop.

## What It Fixes

- **Keyboard backlight control** — color, brightness, and on/off via GUI or CLI
- **Keyboard not responding after suspend** — the i8042 controller fails to reinitialize after S3 deep sleep
- **System76 hotkeys** — Fn key combos for brightness, airplane mode, etc.
- **Power profiles** — balanced, performance, battery via `system76-power`

All of this works out of the box on Pop!_OS but requires manual driver installation on other distros.

## What Gets Installed

| Component | Description |
|-----------|-------------|
| `system76-dkms` | Kernel driver — exposes keyboard backlight, handles hotkeys |
| `system76-power` | Power daemon — manages profiles, backlight brightness |
| `system76-keyboard-configurator` | GUI app — configure keyboard LED colors per zone |
| `fix-keyboard-resume.service` | Systemd service — resets keyboard controller after suspend |
| `i8042.reset=1` | Kernel parameter — forces i8042 reset on resume |

## Requirements

- System76 Pangolin (pang11)
- Debian-based Linux with systemd (Parrot, Ubuntu, Debian, etc.)
- GRUB bootloader
- Internet connection (clones repos during install)
- Root access

## Installation

```bash
git clone https://github.com/chiefgyk3d/pangolin-keyboard-fix.git
cd pangolin-keyboard-fix
sudo bash install.sh
```

Reboot after installation for all changes to take effect.

## Usage

### GUI
Launch **System76 Keyboard Configurator** from your application menu, or run:
```bash
system76-keyboard-configurator
```

### CLI
```bash
# Set all zones to a color (hex RGB)
echo 'ff0000' | sudo tee /sys/class/leds/system76::kbd_backlight/color_{left,center,right,extra}

# Set individual zones
echo '0000ff' | sudo tee /sys/class/leds/system76::kbd_backlight/color_left
echo '00ff00' | sudo tee /sys/class/leds/system76::kbd_backlight/color_center
echo 'ff0000' | sudo tee /sys/class/leds/system76::kbd_backlight/color_right

# Set brightness (0-255, 0 = off)
echo 128 | sudo tee /sys/class/leds/system76::kbd_backlight/brightness

# Check power profile
system76-power profile
```

## Uninstall

```bash
sudo bash uninstall.sh
```

## Tested On

- System76 Pangolin (pang11)
- Parrot Security 7.1 (Debian-based)
- Kernel 6.17.x

Should work on other Debian-based distros with the same hardware.

## License

MIT
