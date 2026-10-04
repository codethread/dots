# Nix → mise: existing Apple Silicon Macs

Final work-machine migration runbook; also usable for personal Macs already using these dotfiles. **Run one step at a time; stop on unexpected errors.** This removes Nix entirely, including its store and project dev-shell support.

The dev Mac mini completed this migration on 2026-10-03. The work machine still needs its own checks; Touch ID was not testable on the Mac mini.

## Before starting

- Have a current backup and local access to the Mac. Keep any existing SSH connection open if you depend on it.
- Use macOS 14+ and a durable dots checkout containing the completed migration changes. **Those changes must reach the other machine first**; an older checkout is not sufficient.
- Homebrew and mise must work independently of Nix. Check `/opt/homebrew/bin/mise --version`; the repo requires mise 2026.9.15 or newer. If missing, install Homebrew from its [official instructions](https://brew.sh), then `/opt/homebrew/bin/brew install mise`.
- **Old Home Manager setup?** Inspect active shell/editor config links now. If they point into `home-manager-files` in the Nix store, complete the [Home Manager handoff](#home-manager-handoff-if-needed) after installing replacements in step 2, before removing nix-darwin. Do not force-overwrite those links.
- For the full work profile, confirm the checkout at `~/pb/adam.hall/workfiles`, GitHub SSH access for private supporting repositories, and cc-notify credentials (`PUSHOVER_CC_KEY` and `PUSHOVER_DEV_KEY` in `~/dev/projects/cc-notify/.env`). Inspect workfiles and project startup hooks for Nix dependencies before removal; this repo does not migrate that separate checkout. Never paste credential values into this guide or logs.
- Do not run `make`, full `mise bootstrap`, LaunchAgent applies, or the new-machine bootstrap until step 8. Normal bootstrap no longer contains one-time Nix-agent guards; the cutover checks below are mandatory.

### Choose the profile

| Machine/account                       | Mise profile |
| ------------------------------------- | ------------ |
| Personal laptop (`codethread`)        | `personal`   |
| Work machine (`adam.hall`/`adamhall`) | `work`       |

**Examples below use `work`; use `personal` for a personal laptop when needed.** Commands are written for Nushell. Keep each command on one logical line when copying. The work profile includes the complete work package and service set.

## 1. Keep a recovery root shell open

In a **separate terminal outside tmux**, use Apple Terminal or another terminal app confirmed not to run from the Nix store:

```nu
sudo /bin/sh
```

Leave it open until the final checks pass. Run everything below in your **normal user terminal**, not that root shell.

## 2. Install the replacements

```nu
cd ~/dev/dots
/opt/homebrew/bin/mise -E work bootstrap packages apply --dry-run
```

Review the preview, then:

```nu
/opt/homebrew/bin/mise -E work bootstrap packages apply
/opt/homebrew/bin/mise -E work install
/bin/ls -l /opt/homebrew/lib/pam/pam_reattach.so
/opt/homebrew/bin/bash --version
```

All must succeed. The last command should show Bash 5+, not macOS's Bash 3.2. These native commands install host packages and mise tools only; they do not change sudo or load services. Missing agent CLIs and repo-specific extras are installed during full bootstrap in step 8. Do not substitute `mise bootstrap --only packages`: that also runs the post-packages sudo-prerequisite hook before retirement.

### Home Manager handoff (if needed)

Skip this subsection if shell/editor configs already resolve to the dots checkout rather than `home-manager-files` in `/nix/store`.

Use a separate historical checkout at revision **`5d48d30795ae553dcee821474444af6cdea982b3`**. Its Home Manager module is minimal but still activates: switching to it unlinks the old managed files. Simply deleting the module does not perform that cleanup. Keep the recovery root shell open.

From that historical checkout, run these **one at a time**, using the same profile as above:

```nu
/opt/homebrew/bin/mise -E work run packages:apply
with-env { PATH: (["/opt/homebrew/bin"] ++ $env.PATH) } { make system work }
/opt/homebrew/bin/mise -E work run workstation:setup
```

The PATH override selects Homebrew Bash for the historical build lock. Use the historical `work` profile for work accounts. Do not run the historical default `make`: it also applies services.

Inspect the active config links again. Stop if any still point at Home Manager's store files or if the historical switch failed; do not force dotty linking. Return to the **current** checkout for step 3 onward. Keep the historical checkout until current boot has relinked its assets. Current dots has no `make system` target.

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

No output means success. Personal/work profiles do **not** install the dev Mac's SSH rules; do not copy its `AllowUsers ct` restriction onto these machines. The dev profile alone manages `/etc/ssh/sshd_config.d/090-dots.conf` with `AllowUsers ct`. For work, record the current effective restrictions (`sudo /usr/sbin/sshd -T`), preserve any required restrictions in a separately reviewed, root-owned file under `/etc/ssh/sshd_config.d/`, and recheck them after retirement. Do not assume removing nix-darwin preserves its configuration files or enables/disables Remote Login.

Then:

```nu
sudo nix --extra-experimental-features 'nix-command flakes' run 'nix-darwin#darwin-uninstaller'
```

Review the prompt and confirm. Wait for `Done!`. **Do not run the store uninstaller yet.**

## 5. Apply mise's system layer and test sudo

```nu
cd ~/dev/dots
./boot/check-system.sh
/opt/homebrew/bin/mise -E work bootstrap files apply
/opt/homebrew/bin/mise -E work bootstrap user apply
/opt/homebrew/bin/mise -E work bootstrap files status
/opt/homebrew/bin/mise -E work bootstrap user status
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

Check all of these legacy labels, including jobs left loaded without a plist:

- `com.codethread.syncengine`
- `com.codethread.backup-notes`
- `com.codethread.cc-notify`
- `com.codethread.git-maintenance.hourly`
- `com.codethread.git-maintenance.daily`
- `com.codethread.git-maintenance.weekly`
- `com.codethread.high-cpu-watch`

Inspect each with `launchctl print gui/UID/LABEL` and its plist with `plutil -p` when present. Remove only confirmed obsolete jobs. If retirement will span a logout/reboot, disable the confirmed old label with `launchctl disable gui/UID/LABEL` before bootout so it cannot reload.

Wait for their child processes to exit, especially syncengine's `gitwatch`/`fswatch` watchers and backup/maintenance Git processes. Inspect processes with `/bin/ps -axo pid,ppid,command`; do not kill unrelated watchers. Repeat `launchctl list` and confirm these labels are absent before starting replacements. Current native bootstrap deliberately does not check legacy labels. Two owners must not run together. **Do not remove `dev.mise.*` jobs.** Save work and exit any other apps, shells or tmux servers still running Nix-store executables; keep the native recovery terminal open. If ownership or shutdown is unclear, stop for inspection.

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

Check that the new login shell no longer sources Nix setup from user rc files, `/etc/zshenv`, `/etc/zprofile`, `/etc/profile`, `/etc/bashrc`, or `/etc/paths.d/`. Inspect leftovers and remove only verified installer-owned snippets/links; do not overwrite unrelated configuration. The installer normally removes its own entries. A fresh login must resolve `bash`, `nu`, `git`, `node`, `bun`, and `mise` outside `/nix`; inherited shells/tmux servers can retain stale PATH entries until restarted.

Then run native mise bootstrap. It needs the machine's GitHub repository access and service credentials; do not force past repository conflicts or missing credentials. LaunchAgents embed this checkout's absolute path: use the durable checkout, not the historical handoff checkout.

```nu
cd ~/dev/dots
/opt/homebrew/bin/bash home/.local/bin/qlock -w 180 /tmp/millstrand-test.lock mise -E work bootstrap
```

**The second line is one command, including `mise …`.** Homebrew Bash avoids the `EPOCHSECONDS` error from macOS Bash 3.2. If `qlock` says `missing CMD`, the line was split: do not run the trailing mise command separately. If the lock wait times out, follow its ticket instructions rather than bypassing it.

After bootstrap, verify:

```nu
/opt/homebrew/bin/mise -E work bootstrap status
/opt/homebrew/bin/mise -E work bootstrap macos launchd-agents status
launchctl list | rg 'dev\.mise\.'
```

The same native status commands select syncengine on `personal` and the complete work service set on `work`. Work should have syncengine, cc-notify, and three Git-maintenance agents, but not dev's backup-notes. Scheduled jobs may be idle; inspect their last exit codes and logs under `~/.local/state/com.codethread.*`.

For work, wait for cc-notify's port file, then check its local health endpoint without sending a real notification:

```nu
let port = (open --raw ~/.local/state/cc-notify/port | str trim)
http get $"http://127.0.0.1:($port)/health"
```

Confirm the old labels remain absent and wait for syncengine startup before checking watcher processes.

When bootstrap, service health, password sudo, and any applicable SSH checks pass, close the recovery root shell. Save work before restarting tmux or rebooting. Empty synthetic `/nix` and `/run` entries can remain until reboot; do not force-delete them.

Keep the recovery directory until post-reboot checks pass. Repeat sudo, SSH (if used), and service checks after reboot.

## 9. Targeted legacy-link and project cleanup

Inspect these leftover links with `/bin/ls -ld` and `/usr/bin/readlink`; unlink only symlinks into removed Home Manager store files, leaving real files, directories and fonts alone:

- `~/.cache/.keep`
- `~/.local/state/.keep`
- `~/Applications/Home Manager Apps`
- `~/Library/Fonts/.home-manager-fonts-version`
- `~/.local/state/home-manager/gcroots/current-home`

Also inspect `~/.config/direnv/lib/nix-direnv.sh`, `~/.config/nushell/direnv.nu`, and the obsolete standalone `~/.local/bin/syncengine`; unlink only links to removed dots files. Syncengine now runs inline in its mise LaunchAgent. Generic Nix profiles belong to the installer flow, not manual recursive deletion. The old `~/dev/vendor/nix-direnv` checkout and unlisted Homebrew packages are not pruned automatically; check other consumers before removing them.

External project `.envrc`/flake workflows need individual migration. Mise's interactive shell hook now selects project `mise.toml` files; `.envrc` is not sourced. Declare tools in `[tools]`, environment in `[env]` (including `_.file` for an existing dotenv file or `_.path` for project bins), then `mise trust`, `mise install`, and `mise exec -- <command>`. Nix syntax support in editors is harmless and remains.

## References and recovery limits

- [nix-darwin uninstalling](https://github.com/nix-darwin/nix-darwin#uninstalling)
- [Lix installer uninstall](https://git.lix.systems/lix-project/lix-installer#uninstalling)
- [Apple sudo extension](https://support.apple.com/en-us/109030), local `/etc/pam.d/sudo_local.template`, and [pam_reattach](https://github.com/fabianishere/pam_reattach)

This is ordered convergence, not a transaction. Stop at a failing phase and preserve the recovery shell, installer copy and full receipt. Do not run a repair/uninstall recipe copied from another machine. The dev Mac's interrupted Lix uninstall required a machine-specific partial receipt; it is not the normal work-machine procedure. Touch ID and the work migration are not claimed as already verified.
