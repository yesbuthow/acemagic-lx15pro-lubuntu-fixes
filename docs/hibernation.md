# Hibernation setup

## Requirements

The tested machine needed:

- Secure Boot disabled;
- a swapfile large enough for the expected hibernation image;
- kernel command-line `resume=` and `resume_offset=`;
- dracut `resume` module in the initrd;
- `HibernateMode=shutdown`.

## 1. Secure Boot

Check:

```bash
mokutil --sb-state
cat /sys/kernel/security/lockdown
```

On the tested system, Secure Boot caused kernel lockdown to restrict hibernation.

## 2. Create swapfile

Example for 20 GiB:

```bash
sudo swapoff /swapfile 2>/dev/null || true
sudo rm -f /swapfile
sudo fallocate -l 20G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

Add:

```text
/swapfile swap swap defaults 0 0
```

to `/etc/fstab`.

## 3. Calculate resume offset

Use:

```bash
./scripts/calc-resume-offset.sh /swapfile
```

Do this **again whenever the swapfile is recreated or moved**.

## 4. Root filesystem UUID

```bash
findmnt -no UUID /
```

Use that UUID in:

```text
resume=UUID=<ROOT_UUID> resume_offset=<OFFSET>
```

inside `GRUB_CMDLINE_LINUX_DEFAULT`.

Then:

```bash
sudo update-grub
```

## 5. Dracut

Install/configure the resume module:

```bash
sudo mkdir -p /etc/dracut.conf.d
sudo cp config/dracut-resume.conf /etc/dracut.conf.d/resume.conf
sudo dracut --regenerate-all --force
```

After reboot:

```bash
cat /sys/power/resume
cat /sys/power/resume_offset
```

`/sys/power/resume` must not be `0:0`.

## 6. Shutdown hibernate mode

```bash
sudo mkdir -p /etc/systemd/sleep.conf.d
sudo cp config/hibernate.conf /etc/systemd/sleep.conf.d/hibernate.conf
```

## 7. Verify capability

```bash
cat /sys/power/state
cat /sys/power/disk
```

The tested system exposed `disk` and supported `shutdown` hibernate mode.
