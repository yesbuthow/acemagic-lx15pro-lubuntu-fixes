# Push this repository to GitHub

After creating an empty repository on GitHub, from the extracted folder:

```bash
git init
git add .
git commit -m "Initial ACEMAGIC LX15PRO Lubuntu fixes"
git branch -M main
git remote add origin git@github.com:YOUR_GITHUB_USER/acemagic-lx15pro-lubuntu-fixes.git
git push -u origin main
```

If GitHub authentication over SSH is not configured, use the repository HTTPS remote instead.

Suggested repository name:

```text
acemagic-lx15pro-lubuntu-fixes
```

Suggested short description:

```text
Lubuntu 26.04 fixes for ACEMAGIC LX15PRO: OEM kernel, dracut hibernation, swapfile resume and AMD/eDP black-screen recovery.
```

Suggested topics:

```text
acemagic
lx15pro
lubuntu
ubuntu
linux
amdgpu
hibernate
dracut
amd
ryzen
edp
```

Before publishing, consider adding a license (MIT/GPL/etc.) according to how you want others to reuse the scripts.
