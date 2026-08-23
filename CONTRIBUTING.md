# Contributing

Reports from other ACEMAGIC LX15PRO hardware revisions are useful.

When opening an issue, please include:

```bash
uname -r
lspci -nnk | grep -A4 -Ei 'VGA|Display|3D'
xrandr --query
cat /sys/power/state
cat /sys/power/disk
cat /sys/power/resume
cat /sys/power/resume_offset
```

For display/resume problems also include:

```bash
sudo journalctl -b -k --no-pager | \
grep -Ei 'amdgpu|DMCUB|dpcd|hibern|resume'
```

Do **not** paste passwords, Windows product keys, SSH keys, tokens or other secrets.
