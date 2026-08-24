# Troubleshooting

## Cold boot says "Image not found"

A normal boot without a stored hibernation image can show:

```text
PM: Image not found
Unable to resume ... continuing boot process
```

That is not automatically a fault. It simply means there was no valid image to restore at that boot.

## `/sys/power/resume` is `0:0`

If `resume_offset` is populated but `resume` remains `0:0`, verify that the dracut `resume` module is inside the initrd:

```bash
sudo lsinitrd /boot/initrd.img-$(uname -r) | grep -iE 'resume|hibernate'
```

Then regenerate:

```bash
sudo dracut --regenerate-all --force
```

## Hibernation works but the displays remain black

Inspect:

```bash
sudo journalctl -b -k --no-pager | \
grep -Ei 'amdgpu|DMCUB|dpcd|hibern|resume'
```

On the tested machine, the RAM image restored correctly while AMDGPU logged DMCUB errors.

Manual recovery that worked:

```bash
xrandr --output eDP --off
sleep 0.2
xrandr --output eDP --auto
xset s reset
xset dpms force on
```

The `iberna-smart` script automates this.

## No password after resume

On the tested Lubuntu/X11 setup both LXQt Session and XScreenSaver could participate in pre-sleep locking.

Check:

```bash
systemd-inhibit --list | grep -Ei 'LXQt Session|xscreensaver'
```

The final working setup had:

```text
xscreensaver ... sleep ... lock screen on suspend ... delay
```

but **not**:

```text
LXQt Session ... Start screen locker before sleep
```

Set:

```ini
[General]
lock_screen_before_power_actions=false
```

in:

```text
~/.config/lxqt/session.conf
```

Then let `iberna-smart` explicitly run:

```bash
xscreensaver-command -lock
```

before hibernation.

## `systemctl hibernate` returns too early

A useful discovery from testing: an unprivileged `systemctl hibernate` request can return control to the caller before `systemd-hibernate.service` has materially entered the sleep path.

A naive post-resume script may therefore execute **before the machine has actually hibernated**.

The final wrapper deliberately leaves a short synchronization margin (`sleep 0.75`). Once the sleep transition starts, that process itself is frozen; on resume only the remaining fraction is paid.

This eliminated a race observed during testing.

## Laptop-only resume: do not reset an already-active eDP link

A later test exposed an important special case:

- the laptop was hibernated with only the internal eDP panel active;
- after resume the desktop appeared briefly;
- forcing `xrandr --output eDP --off` followed by `--auto` triggered repeated
  DMCUB/DPCD errors and eventually:

```text
enabling link 0 failed: 15
```

The correct workaround was **not** to reset the panel in this case.

If eDP was already active before hibernation and no external display is active
after resume, `iberna-smart` now leaves the eDP link untouched and only wakes
DPMS after display handling is complete.

This avoids forcing AMDGPU to perform another eDP link-training cycle while
the display engine is still recovering.

The eDP OFF/ON recovery is still useful when eDP was previously disabled
(for example, the laptop was used only with an external monitor) and the
external monitor is no longer present after resume.

## Lock screen synchronization

Another observed race was that requesting the XScreenSaver lock and sleeping
for a fixed delay did not prove that the lock screen was actually ready before
hibernation.

The wrapper now starts:

```bash
xscreensaver-command -watch
```

before requesting the lock and waits for the explicit:

```text
LOCK ...
```

event. Hibernation is aborted if XScreenSaver does not confirm the lock.

The early post-resume `xset dpms force on` was also removed. DPMS is now
forced on only after display handling, which prevents the desktop from being
briefly exposed before the lock screen has been redrawn.

