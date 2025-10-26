# Boot Configuration - dyckymost (Raspberry Pi 4B)

## Console-Only Mode (No GUI)

**Default systemd target:** `multi-user.target`

```bash
# Check current target
systemctl get-default
# Output: multi-user.target

# Symlink location
ls -la /etc/systemd/system/default.target
# Output: /etc/systemd/system/default.target -> /lib/systemd/system/multi-user.target
```

**How this was configured:**
```bash
# Switch to console-only (disable GUI)
sudo systemctl set-default multi-user.target

# To switch back to GUI (if needed in future)
sudo systemctl set-default graphical.target
```

**Status:**
- ✅ Boots to console only
- ✅ No X server or desktop environment started
- ✅ Saves memory and CPU resources
- ✅ Suitable for headless router operation

**Display Manager Status:**
- `lightdm.service` is **enabled** but doesn't start
- Reason: `multi-user.target` doesn't depend on `graphical.target`
- The systemd default target determines what services start

**Note:** Desktop packages (lightdm, gnome libraries) remain installed but are not loaded at boot due to multi-user.target.

## Restoration

To restore this configuration on a fresh install:
```bash
sudo systemctl set-default multi-user.target
sudo reboot
```
