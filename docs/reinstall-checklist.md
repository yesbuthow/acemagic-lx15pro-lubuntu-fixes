# Reinstall checklist

Use this only as a reconstruction guide. Re-check hardware, UUIDs and kernel versions after reinstalling.

1. Install Lubuntu 26.04.
2. Verify hardware (`lspci -nnk`, `lsblk`, `xrandr`).
3. Install `linux-oem-26.04`.
4. Boot a known-good OEM kernel.
5. Disable Secure Boot if hibernation is blocked by lockdown.
6. Create `/swapfile`.
7. Calculate a **new** `resume_offset`.
8. Add `resume=UUID=... resume_offset=...` to GRUB.
9. Add dracut `resume` module.
10. Regenerate initrd and GRUB.
11. Set `HibernateMode=shutdown`.
12. Install/configure XScreenSaver.
13. Set `lock_screen_before_power_actions=false`.
14. Install Polkit hibernate rule, replacing `YOUR_USER`.
15. Install `scripts/iberna-smart` in `~/.local/bin/`.
16. Create the desktop launcher.
17. Verify `CanHibernate` returns `yes`.
18. Test hibernation with all important work saved.
19. Verify display recovery and password lock.
20. Inspect logs before considering the setup stable.

## Do not blindly reuse

- old filesystem UUIDs;
- old swapfile `resume_offset`;
- old kernel numbers;
- old DRM connector names if the hardware/driver changed.
