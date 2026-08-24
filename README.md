# ACEMAGIC LX15PRO + Lubuntu 26.04: OEM kernel, hibernation and AMD/eDP fixes

Community notes and scripts for a specific ACEMAGIC LX15PRO configuration tested with:

- **CPU:** AMD Ryzen 7 7730U
- **iGPU:** AMD Radeon Barcelo/Renoir (`1002:15e7`)
- **OS:** Lubuntu 26.04 LTS
- **Display:** internal eDP panel + optional external DisplayPort/HDMI
- **Tested working kernel:** `7.0.0-1011-oem`

This repository documents a set of fixes discovered while troubleshooting three related problems:

1. the internal display could boot black on generic kernels;
2. hibernation initially failed because the resume device was not populated in the initrd;
3. after successful hibernation/resume, AMDGPU could restore the session while leaving displays black until a keyboard/power event woke them.

The final setup uses the Ubuntu OEM kernel, `dracut` resume support, a swapfile with `resume_offset`, `HibernateMode=shutdown`, XScreenSaver locking, and a small `iberna-smart` wrapper that repairs display state after resume.

> This is **not** an official ACEMAGIC or Ubuntu project. ACEMAGIC may ship different hardware revisions under the same model name. Verify your hardware before applying anything.

## Start here: which problem do you have?

You do **not** necessarily need every fix in this repository.

### A. Internal screen is black during a normal boot

Symptoms:

- Lubuntu starts but the internal eDP panel remains black;
- booting with an external HDMI/DisplayPort monitor may behave differently;
- `nomodeset` may make the machine boot, but disables normal AMDGPU acceleration.

Start with the **Ubuntu OEM kernel** section below. On the tested machine,
`7.0.0-1011-oem` fixed normal boot of the internal display.

### B. Normal boot works, but hibernation is unavailable or does not resume

Start with [`docs/hibernation.md`](docs/hibernation.md).

The complete setup covers Secure Boot/kernel lockdown, swapfile creation,
`resume_offset`, GRUB, the `dracut` resume module and
`HibernateMode=shutdown`.

### C. Hibernation restores the session, but the display stays black

Start with [`scripts/iberna-smart`](scripts/iberna-smart) and
[`docs/troubleshooting.md`](docs/troubleshooting.md).

On the tested machine, AMDGPU restored the hibernated session correctly while
the display path remained black and the kernel logged DMCUB-related errors.
Resetting the internal eDP output and forcing DPMS on recovered it.

---

## Fresh Lubuntu 26.04 -> working hibernation

If you are starting from a fresh Lubuntu installation and want to reproduce
the complete tested setup, use this order:

1. **Verify that your hardware matches the tested system.**

   See [`hardware/tested-system.txt`](hardware/tested-system.txt). ACEMAGIC may
   ship different hardware revisions under the same product name.

2. **Install the Ubuntu OEM kernel.**

   ```bash
   sudo apt update
   sudo apt install linux-oem-26.04
   ```

   Reboot and check:

   ```bash
   uname -r
   ```

   The known-good kernel during testing was `7.0.0-1011-oem`. Treat that as a
   tested reference, not a version to pin forever.

3. **Check whether Secure Boot / lockdown blocks hibernation.**

   ```bash
   mokutil --sb-state
   cat /sys/kernel/security/lockdown
   cat /sys/power/state
   ```

   On the tested machine, Secure Boot had to be disabled before `disk`
   became available as a sleep state.

4. **Create a swapfile.**

   The tested setup used 20 GiB:

   ```bash
   sudo swapoff /swapfile 2>/dev/null || true
   sudo rm -f /swapfile
   sudo fallocate -l 20G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   ```

   Add this to `/etc/fstab`:

   ```text
   /swapfile swap swap defaults 0 0
   ```

5. **Calculate your own `resume_offset`.**

   ```bash
   ./scripts/calc-resume-offset.sh /swapfile
   ```

   **Never copy the offset from another machine or from an older swapfile.**
   Recalculate it whenever `/swapfile` is recreated or moved.

6. **Find the filesystem UUID containing the swapfile.**

   ```bash
   findmnt -no UUID /
   ```

   Add both values to `GRUB_CMDLINE_LINUX_DEFAULT`:

   ```text
   resume=UUID=<YOUR_ROOT_UUID> resume_offset=<YOUR_RESUME_OFFSET>
   ```

   Then:

   ```bash
   sudo update-grub
   ```

7. **Enable resume support in dracut.**

   ```bash
   sudo mkdir -p /etc/dracut.conf.d
   sudo cp config/dracut-resume.conf /etc/dracut.conf.d/resume.conf
   sudo dracut --regenerate-all --force
   ```

   Reboot and verify:

   ```bash
   cat /sys/power/resume
   cat /sys/power/resume_offset
   ```

   `/sys/power/resume` should no longer be `0:0`.

8. **Use full shutdown after writing the hibernation image.**

   ```bash
   sudo mkdir -p /etc/systemd/sleep.conf.d
   sudo cp config/hibernate.conf /etc/systemd/sleep.conf.d/hibernate.conf
   ```

9. **Configure the screen lock.**

   The tested Lubuntu/X11 system used XScreenSaver. LXQt's additional
   pre-sleep locker was disabled with:

   ```ini
   [General]
   lock_screen_before_power_actions=false
   ```

   See [`config/lxqt-session-snippet.ini`](config/lxqt-session-snippet.ini).

10. **Allow the active local user to request hibernation.**

    Copy and edit
    [`config/polkit-hibernate.rules.example`](config/polkit-hibernate.rules.example),
    replacing `YOUR_USER` with the local username.

11. **Install the smart hibernation wrapper.**

    ```bash
    mkdir -p ~/.local/bin
    cp scripts/iberna-smart ~/.local/bin/iberna-smart
    chmod +x ~/.local/bin/iberna-smart
    ```

12. **Optionally create the desktop launcher.**

    Start from [`config/Iberna.desktop.example`](config/Iberna.desktop.example)
    and replace `YOUR_USER`.

13. **Test with important work saved.**

    ```bash
    cat /sys/power/state
    cat /sys/power/disk
    ~/.local/bin/iberna-smart
    ```

14. **Inspect the result.**

    ```bash
    journalctl -b --no-pager -o short-monotonic | \
    grep -Ei 'Performing sleep operation|System returned from sleep operation|iberna-smart|hibernate'
    ```

For the detailed explanation of every step, see
[`docs/hibernation.md`](docs/hibernation.md).

---

## What worked

### 1. OEM kernel

The generic kernels tested behaved differently:

- `7.0.0-30-generic`: severe black-screen / AMDGPU problems.
- `7.0.0-14-generic`: GPU acceleration worked, but the internal panel could stay black at boot unless HDMI was already connected.
- `7.0.0-1011-oem`: internal display booted correctly without HDMI and became the known-good kernel.

Install the OEM meta-package:

```bash
sudo apt update
sudo apt install linux-oem-26.04
```

Verify:

```bash
uname -r
```

### 2. Hibernation via swapfile

A 20 GiB swapfile was used. The hibernation image is located by both:

- the filesystem UUID containing the swapfile;
- the swapfile physical `resume_offset`.

See [`docs/hibernation.md`](docs/hibernation.md).

### 3. Ubuntu 26.04 / dracut resume

The kernel command line already contained `resume=` and `resume_offset=`, but:

```text
/sys/power/resume = 0:0
```

while `/sys/power/resume_offset` was populated.

Adding the dracut `resume` module and regenerating the initrd caused the correct root device major:minor to be written to `/sys/power/resume`.

See [`config/dracut-resume.conf`](config/dracut-resume.conf).

### 4. AMD/eDP resume workaround

After hibernation, the session could restore correctly while both displays remained black. Kernel logs repeatedly showed DMCUB errors during AMDGPU display resume.

A manual:

```bash
xrandr --output eDP --off
sleep 0.2
xrandr --output eDP --auto
xset s reset
xset dpms force on
```

reliably recovered the internal display.

The final [`scripts/iberna-smart`](scripts/iberna-smart) wrapper:

- locks XScreenSaver first;
- waits for XScreenSaver to emit a real `LOCK` event before requesting hibernation;
- hibernates without requiring a root password when the Polkit rule is installed;
- detects whether the internal eDP panel was enabled before hibernation;
- detects whether an external monitor exists after resume;
- automatically enables eDP if the laptop wakes away from the desk;
- leaves an already-active laptop-only eDP link untouched after resume, avoiding a fragile extra AMDGPU/DPCD link-training cycle;
- otherwise preserves the user's monitor layout;
- performs the fast eDP reset only when needed;
- forces DPMS back on.

In the final measured test, the display-fix overhead after the kernel returned from hibernation was about **0.15 s**.

## Quick layout

```text
.
├── README.md
├── README_IT.md
├── docs/
│   ├── hibernation.md
│   ├── troubleshooting.md
│   └── reinstall-checklist.md
├── scripts/
│   ├── iberna-smart
│   └── calc-resume-offset.sh
├── config/
│   ├── dracut-resume.conf
│   ├── hibernate.conf
│   ├── polkit-hibernate.rules.example
│   ├── lxqt-session-snippet.ini
│   └── Iberna.desktop.example
├── hardware/
│   └── tested-system.txt
└── PUSH_TO_GITHUB.md
```

## Important warnings

- **Back up your data before testing hibernation.**
- A hibernation image in an **unencrypted swapfile may contain sensitive data from RAM**.
- This setup required **Secure Boot to be disabled**, because kernel lockdown blocked hibernation on the tested system.
- **Never copy an old `resume_offset` after recreating `/swapfile`.** Recalculate it.
- Do not blindly pin `7.0.0-1011-oem` forever. It is the known-good tested kernel, but future OEM kernels may contain better fixes.

## Logs useful for debugging

```bash
journalctl -t iberna-smart --no-pager -n 30
```

```bash
journalctl -b --no-pager -o short-monotonic | \
grep -Ei 'Performing sleep operation|System returned from sleep operation|iberna-smart|hibernate'
```

```bash
sudo journalctl -b -k --no-pager | \
grep -Ei 'amdgpu|DMCUB|dpcd|hibern|resume'
```

## License

No license has been selected yet. Add one before encouraging third-party redistribution or modification.
