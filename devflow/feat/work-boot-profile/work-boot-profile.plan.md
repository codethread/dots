# Work Boot Profile Plan

Document ID: PLAN-001
Status: Reviewed
Last Updated: 2026-06-24

## [PLAN-001-S1] Goal and scope

[PLAN-001-S1.1] Add a minimal work boot path for unknown work usernames while keeping full `#work` tied to the current full-work machine username.

## [PLAN-001-S2] Approach

[PLAN-001-S2.1] Model boot as separate Darwin flake outputs: `work-boot` for `adam.hall` and `work-adamhall-boot` for `adamhall`.

[PLAN-001-S2.2] Keep full `#work` as the only full work output and point it at the current `adamhall` host module/profile.

[PLAN-001-S2.3] Teach `nrs` default resolution to use `$HOME/pb/adam.hall/workfiles`: present means full `work`, absent means username-specific boot.

[PLAN-001-S2.4] Teach `boot/boot.sh` to default work usernames to boot outputs because fresh machines may not have workfiles yet.

## [PLAN-001-S3] Affected areas

- [PLAN-001-S3.1] `nix/flake.nix`
- [PLAN-001-S3.2] `nix/hosts/darwin/`
- [PLAN-001-S3.3] `nix/profiles/`
- [PLAN-001-S3.4] `config/nushell/scripts/ct/nix.nu`
- [PLAN-001-S3.5] `boot/boot.sh`
- [PLAN-001-S3.6] `devflow/specs/nix-infra.md`

## [PLAN-001-S4] Implementation phases

- [PLAN-001-S4.1] Add boot host/profile modules and flake outputs.
- [PLAN-001-S4.2] Update bootstrap and rebuild profile resolution.
- [PLAN-001-S4.3] Refresh SPEC-006 sections that describe system configurations, bootstrap, and profile resolution.
- [PLAN-001-S4.4] Validate Nix evaluation for the changed Darwin outputs.

## [PLAN-001-S5] Validation strategy

- [PLAN-001-S5.1] Run `nix flake show path:./nix` or targeted `nix eval` for new outputs.
- [PLAN-001-S5.2] Run `nu-check` on the edited Nushell module.
- [PLAN-001-S5.3] Run shell syntax check for `boot/boot.sh`.

## [PLAN-001-S6] Task context

[PLAN-001-S6.1] This is small enough to execute directly from the reviewed plan without AFK task slicing.

## [PLAN-001-S7] Developer Notes

- [PLAN-001-S7.1] 2026-06-24: Plan created from user direction; current local username is `adamhall`, and `$HOME/pb/adam.hall/workfiles` exists on this machine.
