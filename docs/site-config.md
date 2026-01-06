# Site config (roosevelt)

LAN: 192.168.69.0/24

# Setting this in my inventory to deploy single node clusters on. Once my other
# nodes are online I will switch to only running to tofu to spin up the clusters
# on the 3 nodes.
Dev Box:
- sharin: 192.168.69.10

Nodes:
- peter1: 192.168.69.11
- peter2: 192.168.69.12
- peter3: 192.168.69.13

MetalLB pool:
- 192.168.69.200-192.168.69.210
