# Nix → mise: existing Apple Silicon Macs

For the personal and work Macs already using these dotfiles. **Run one step at a time; stop on unexpected errors.** This removes Nix entirely, including its store and project dev-shell support.

The dev Mac mini completed this migration on 2026-10-03. Personal/work machines still need their own checks; Touch ID was not testable on the Mac mini.

## Before starting

- Have a current backup and local access to the Mac. Keep any existing SSH connection open if you depend on it.
- Use macOS 14+ and a durable dots checkout containing the completed migration changes. **Those changes must reach the other machine first**; an older checkout is not sufficient.
- Homebrew and mise must work independently of Nix. Check `/opt/homebrew/bin/mise --version`; the repo requires mise 2026.9.15 or newer. If missing, install Homebrew from its [official instructions](https://brew.sh), then `/opt/homebrew/bin/brew install mise`.
- **Old Home Manager setup?** Complete the [Home Manager handoff](mise.md#retiring-home-manager-on-existing-machines) before removing nix-darwin. If active shell/editor configs still point into `home-manager-files` in the Nix store, stop here. Do not force-overwrite those links.
- Do not run `make`, `mise run boot`, or the new-machine bootstrap until step 8.

### Choose the profile

| Machine/account                                        | Mise profile |
| ------------------------------------------------------ | ------------ |
| Personal laptop (`codethread`)                         | `personal`   |
| Full work setup (`adamhall`, with workfiles installed) | `work`       |
| Work bootstrap account/setup                           | `work-boot`  |

**Examples below use `personal`. Replace it with `work` or `work-boot` in every mise command as appropriate.** Commands use syntax that works in both Nushell and Zsh. Keep each command on one logical line when copying.

## 1. Keep a recovery root shell open

In a **separate terminal outside tmux**, use Apple Terminal or another terminal app confirmed not to run from the Nix store:

```nu
sudo /bin/sh
```

Leave it open until the final checks pass. Run everything below in your **normal user terminal**, not that root shell.

## 2. Install the replacements

```nu
cd ~/dev/dots
/opt/homebrew/bin/mise -E personal bootstrap packages apply --dry-run
```

Review the preview, then:

```nu
/opt/homebrew/bin/mise -E personal run packages:apply
/bin/ls -l /opt/homebrew/lib/pam/pam_reattach.so
/opt/homebrew/bin/bash --version
```

All must succeed. The last command should show Bash 5+, not macOS's Bash 3.2.

## 3. Save the installer and full receipt outside the Nix volume

**Do this before uninstalling anything.** The Lix installer we encountered only relocated itself automatically when named exactly `/nix/lix-installer`. Running that binary as `/nix/nix-installer` made it force-unmount its own executable and hang.

Inspect what this machine has:

```nu
/bin/ls -l /nix
```

You need its installed `nix-installer` or `lix-installer` and `receipt.json`. If both installers exist, identify the one matching the receipt before proceeding. If neither exists, or there is no receipt, stop: this machine needs its installer's own uninstall procedure.

Create a private recovery directory. If it already exists, stop and inspect the previous attempt rather than overwriting it.

```nu
/bin/mkdir -m 700 ~/nix-retirement
cd ~/nix-retirement
/bin/cp /nix/receipt.json ./receipt.json
```

For a machine with **`nix-installer`**:

```nu
/bin/cp /nix/nix-installer ./installer
/usr/bin/cmp /nix/nix-installer ./installer
```

For a machine with **`lix-installer`**, use these two commands **instead**:

```nu
/bin/cp /nix/lix-installer ./installer
/usr/bin/cmp /nix/lix-installer ./installer
```

Verify the receipt copy and inspect the installed version/usage:

```nu
/usr/bin/cmp /nix/receipt.json ./receipt.json
./installer --version
./installer uninstall --help
jq -r .version ./receipt.json
```

`cmp` should print nothing and succeed. Confirm the installer matches its receipt and supports the receipt argument. Keep the **full, unedited receipt**; the volume-only recovery receipt used on the dev Mac was specific to its interrupted attempt.

## 4. Retire nix-darwin, not the store

If Remote Login is enabled, validate SSH first and preserve any Nix-owned SSH restrictions before removing their owner:

```nu
sudo /usr/sbin/sshd -t
```

No output means success. Personal/work profiles do **not** install the dev Mac's SSH rules; do not copy its `AllowUsers ct` restriction onto these machines. The [dev-only SSH handoff](mise.md#dev-ssh-server) is separate.

Then:

```nu
sudo nix --extra-experimental-features 'nix-command flakes' run 'nix-darwin#darwin-uninstaller'
```

Review the prompt and confirm. Wait for `Done!`. **Do not run the store uninstaller yet.**

## 5. Apply mise's system layer and test sudo

```nu
cd ~/dev/dots
/opt/homebrew/bin/mise -E personal run system:apply
/opt/homebrew/bin/mise -E personal run system:status
```

Expect login shell `/bin/zsh` and a regular, mise-managed sudo extension owned by `root:wheel`, mode `0644`. If it still reports a Nix-owned symlink or a missing PAM include, stop; do not bypass the checks.

Force fresh authentication:

```nu
sudo -k
sudo -v
```

Repeat in a normal terminal **and inside tmux**. On Touch ID-capable machines, test both fingerprint authentication and password entry, running `sudo -k` before each attempt. Without suitable hardware, verify the password path and record Touch ID as untested.

## 6. Retire leftover old jobs

The nix-darwin uninstaller may leave user jobs loaded. Inspect:

```nu
launchctl list | rg 'com\.codethread\.'
id -u
```

For each confirmed **old Nix-backed** job, unload it and remove only its obsolete plist. For example, replace `UID` below with the number from `id -u`; run this only if that old watcher exists:

```nu
launchctl bootout gui/UID/com.codethread.high-cpu-watch
/bin/rm ~/Library/LaunchAgents/com.codethread.high-cpu-watch.plist
```

Other old jobs can include syncengine, backup-notes, cc-notify and Git maintenance. Inspect their executable paths; wait for their child processes to exit before proceeding. **Do not remove `dev.mise.*` jobs.** Save work and exit any other apps, shells or tmux servers still running Nix-store executables; keep the native recovery terminal open. If ownership or shutdown is unclear, stop for inspection.

Check for the Lix repair hook:

```nu
sudo launchctl print system/systems.lix.nix-installer.nix-hook
```

“Could not find service” means it is already absent. If it is loaded, unload it:

```nu
sudo launchctl bootout system/systems.lix.nix-installer.nix-hook
```

Leave the actual Nix daemon and volume-mount service to the installer in the next step.

## 7. Remove the Nix store using the saved copy

```nu
cd ~/nix-retirement
sudo ./installer uninstall ./receipt.json
```

Review the plan against **this machine's** installation and confirm. Wait for the success message. The executable and receipt are now outside the volume being removed.

**If it hangs or errors, stop and keep the recovery shell open.** Do not reboot, run `repair`, delete the volume manually, or reuse another machine's PID/disk identifier. Never `rm -rf /nix`.

## 8. Verify and apply the current environment

Open a **fresh terminal outside tmux**, keeping the recovery root shell open:

```nu
sudo -k
sudo -v
/usr/sbin/diskutil list
sudo launchctl list | rg -i 'nix|lix'
```

Confirm the Nix Store volume and Nix jobs are gone; no matches from `rg` is expected. Check that `/usr/bin/which mise` resolves outside the Nix store (normally `/opt/homebrew/bin/mise`). Re-test password sudo in tmux. If Remote Login is enabled, re-run `sudo /usr/sbin/sshd -t` and test a new SSH connection before closing the existing one.

Then run the full mise path. It needs the machine's GitHub repository access and service credentials; do not force past repository conflicts or missing credentials.

```nu
cd ~/dev/dots
/opt/homebrew/bin/bash home/.local/bin/qlock -w 180 /tmp/millstrand-test.lock mise -E personal run boot
```

**The second line is one command, including `mise …`.** Homebrew Bash avoids the `EPOCHSECONDS` error from macOS Bash 3.2. If `qlock` says `missing CMD`, the line was split: do not run the trailing mise command separately. If the lock wait times out, follow its ticket instructions rather than bypassing it.

When boot, password sudo, and any applicable SSH checks pass, close the recovery root shell. Save work before restarting tmux or rebooting. Empty synthetic `/nix` and `/run` entries can remain until reboot; do not force-delete them.

Keep the recovery directory until post-reboot checks pass. Finish the [targeted legacy-link cleanup](mise.md#retiring-home-manager-on-existing-machines), and migrate external projects' `.envrc`/flake workflows individually. Nix syntax support in editors is harmless and can remain.
