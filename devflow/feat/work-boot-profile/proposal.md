# Work Boot Profile Proposal

Document ID: PROP-001
Status: Accepted

## [PROP-001-S1] Problem

[PROP-001-S1.1] New work macOS machines may be provisioned with either `adam.hall` or `adamhall` as the local username, and the private workfiles repository may not exist yet. The public dotfiles bootstrap needs a safe work-specific profile that can build before private work configuration is installed.

## [PROP-001-S2] Goals

- [PROP-001-S2.1] Provide username-specific boot flake outputs for `adam.hall` and `adamhall`.
- [PROP-001-S2.2] Keep the boot profile minimal: shared dev setup plus `glab`.
- [PROP-001-S2.3] Make normal rebuild helpers choose full work only when `$HOME/pb/adam.hall/workfiles` exists.
- [PROP-001-S2.4] Nudge the operator after boot to install workfiles and switch to `#work`.
- [PROP-001-S2.5] Update SPEC-006 to match current profile resolution and work boot behavior.

## [PROP-001-S3] Non-goals

- [PROP-001-S3.1] Do not make private workfiles a flake input.
- [PROP-001-S3.2] Do not implement optional impure private module imports in this change.
- [PROP-001-S3.3] Do not keep two full work profiles for both usernames; `#work` tracks the current known full-work username.

## [PROP-001-S4] Proposed scope

[PROP-001-S4.1] Add public work boot host/profile outputs, update bootstrap and Nushell profile resolution, and refresh the canonical Nix infrastructure spec.

## [PROP-001-S5] Relevant specs

- [SPEC-006 nix-infra](../../specs/nix-infra.md)

## [PROP-001-S6] Open questions

- [PROP-001-S6.1] None for this slice.
