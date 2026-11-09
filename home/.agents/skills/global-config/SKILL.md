---
name: global-config
description: Use when changing something outside the current project like a brew package or system dependency
---

This machine is managed through a central dotfiles repo, with a supporting workfiles repo if its a work device:

- ~/dev/dots/
- ~/pb/adam.hall/workfiles/

Global systems are managed through `dots`, or if work specific, `workfiles`. Always send an agent to check alignment with these repos first, following the respective guidance in each (best done through a dedicated agent spawned in said repos)
