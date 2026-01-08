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

## Oooo My Notes

### My Setup
#### Bare metal
3x Lenovo Thinkstations for main k8s lab
- 12th Gen Intel(R) Core(TM) i5-12500 6 core(12 threads)
- 64GB Ram
- hostnames: peter1, peter2, peter3

Intel NUC for development, orchestration and testing
- 12th Gen Intel(R) Core(TM) i9-12900
- 64GB Ram
- hostname: sharin

### Orchestration
#### Lenovo node setup

Using Ansible for node setup called via maru tasks

- Installed ubuntu with ubuntu user
- Set up ssh
- ran ansible from sharin to do more setup

```
#### passwordless ssh
ssh-copy-id -i ~/.ssh/project_roosevelt_ed25519.pub ubuntu@peter1
ssh-copy-id -i ~/.ssh/project_roosevelt_ed25519.pub ubuntu@peter2
ssh-copy-id -i ~/.ssh/project_roosevelt_ed25519.pub ubuntu@peter3

#### passwordless sudo
# check
sudo -n true 2>/dev/null && echo "already passwordless sudo" || echo "sudo still requires password"

# fix if it requires it
sudo bash -c 'printf "ubuntu ALL=(ALL) NOPASSWD:ALL\n" >/etc/sudoers.d/99-ubuntu-nopasswd && chmod 440 /etc/sudoers.d/99-ubuntu-nopasswd'

# verify
sudo -n true && echo "passwordless sudo OK"

#### ansible prep
uds run ansible:prep
```

#### k8s deployment

Using Tofu for k8s orchestration called via maru tasks

node inventory to deploy k8s to [inventory/nodes.yaml](inventory/nodes.yaml)

example
```
# project-roosevelt inventory
# Scope: local network only
# Secrets: none

ssh_user: ubuntu

nodes:
  # - name: sharin
  #   host: sharin
  #   role: controlplane
  #   node_ip: 192.168.69.10

  - name: peter1
    host: peter1
    role: controlplane
    node_ip: 192.168.69.11
    labels:
      roosevelt.node: holland

  - name: peter2
    host: peter2
    role: worker
    node_ip: 192.168.69.12
    labels:
      roosevelt.node: maguire

  - name: peter3
    host: peter3
    role: worker
    node_ip: 192.168.69.13
    labels:
      roosevelt.node: garfield
```

tasks to execute

```
# Stand up k3s on nodes in inventory
uds run k3s-lab-up
# Tear down k3s on nodes in inventory
uds run k3s-lab-up

# k0s stands up but networking is messed up at the moment
# Stand up k0s on nodes in inventory
uds run k0s-lab-up
# Tear down k3s on nodes in inventory
uds run k0s-lab-up
```

#### Docker will break at the moment
If this is run on a machine that uses docker for things like k3d, this will break the networking. This happened when I was testing on sharin before my peter nodes came in. This project is doing things with iptables. This may be wrong or need worked but it is what it is right now.

To get docker networking back
```
# 1) Switch alternatives back to nft (Docker-friendly default on Ubuntu)
sudo update-alternatives --set iptables /usr/sbin/iptables-nft
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-nft || true
sudo update-alternatives --set arptables /usr/sbin/arptables-nft || true
sudo update-alternatives --set ebtables /usr/sbin/ebtables-nft || true

# 2) Restart Docker so it recreates the right chains in the right backend
sudo systemctl restart docker
```

## DoTheDew

```bash
uds run --list
k3s-lab-up              | Stand up k3s cluster in lab environment                                                   
k3s-lab-down            | Tear down k3s cluster in lab environment                                                  
k0s-lab-up              | Stand up k0s cluster in lab environment                                                   
k0s-lab-down            | Tear down k0s cluster in lab environment                                                  
lab-kubeconfig          | Get the kubeconfig path for the lab environment                                           
lab-status              | Get the status of the lab environment                                                     
full-bootstrap          | Create and deploy the bootstrap bundle, then create a Keycloak user                       
create-bootstrap-bundle | Create the core-secrets package and bootstrap bundle                                      
deploy-bootstrap-bundle | Deploy the bootstrap bundle to the cluster                                                
create-keycloak-user    | Add a new keycloak user to the cluster for testing purposes                               
ansible-prep            | Run Ansible node prep against the current ansible/inventory.ini to prep fresh ubuntu nodes 
```