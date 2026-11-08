# Bootstrap scripts

- Keep native resources in mise; scripts here cover ordering-sensitive preparation or checks that mise cannot model declaratively.
- Preserve phase order: PAM safety and Ruby precede packages, remaining tools precede repositories, and `boot/setup.sh` prepares dependencies before dotfiles and LaunchAgents consume them. A final bootstrap task is too late for those consumers.
- Keep `boot/check-system.sh --pre-packages` limited to checks valid before package installation. The no-argument form also requires the installed `pam-reattach` module and is the prerequisite for an authorized manual managed-file apply.
- Bootstrap is not transactional: fail loudly before unsafe convergence because completed earlier phases remain applied.
- Run the bootstrap checks in [the verification guide](../docs/verification.md#mise-and-bootstrap); host apply and service operations require explicit authorization.
