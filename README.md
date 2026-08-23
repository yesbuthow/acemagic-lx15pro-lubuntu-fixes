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
- hibernates without requiring a root password when the Polkit rule is installed;
- detects whether the internal eDP panel was enabled before hibernation;
- detects whether an external monitor exists after resume;
- automatically enables eDP if the laptop wakes away from the desk;
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
