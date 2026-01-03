# project-roosevelt

Rebuildable bare-metal Kubernetes lab for my platform playground.

- Inventory-driven node roles
- OpenTofu orchestrated lifecycle over SSH
- UDS maru tasks as the interface
- Switchable Kubernetes distros (k3s first; k0s/rke2 later)

Primary goals:
- Safe, repeatable rebuilds
- Clear automation structure
- Extensible for UDS Core + GitLab and beyond
