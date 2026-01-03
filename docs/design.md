# Design

## Goals
- Spin up and tear down Kubernetes clusters on my bare metal servers
- Support multiple Kubernetes distros (k3s → k0s/rke2 later)
- Use OpenTofu to orchestrate node lifecycle over SSH
- Use UDS maru tasks as the UX layer
- Later support UDS Core + UDS packages (GitLab)

## Topology
Phase 1 (now): single-node on sharin to validate workflow
Phase 2: 1 control plane + 2 workers on peter1–3

## Naming
- sharin = control/automation box (Web Slingers ai assistant nod)
- peter1 peter2 peter3 = cluster nodes (Spiderman No Way Home team)
- future node labels map to actors:
  - peter1=holland, peter2=maguire, peter3=garfield
