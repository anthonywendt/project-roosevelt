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

## DoTheDew

```bash
uds run --list
k3s-full                | Bring up the k3s lab and build/deploy the bootstrap bundle         
k3s-lab-up              | Bring up the lab environment through k8s                           
k3s-lab-down            | Bring down the lab environment through k8s                         
lab-kubeconfig          | Get the kubeconfig path for the lab environment                    
lab-status              | Get the status of the lab environment                              
k0s-lab-up              | Bring up the k0s lab environment through k8s                       
k0s-lab-down            | Bring down the k0s lab environment through k8s                     
full-bootstrap          | Create and deploy the bootstrap bundle, then create a Keycloak user
create-bootstrap-bundle | Create the core-secrets package and bootstrap bundle               
deploy-bootstrap-bundle | Deploy the bootstrap bundle to the cluster                         
create-keycloak-user    | Add a new keycloak user to the cluster for testing purposes 
```