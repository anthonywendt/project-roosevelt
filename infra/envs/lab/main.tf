locals {
  inventory_path = abspath("${path.module}/../../../${var.inventory_file}")
  inv            = yamldecode(file(local.inventory_path))

  ssh_user = local.inv.ssh_user

  ssh_key_path    = "~/.ssh/project_roosevelt_ed25519"
  ssh_private_key = file(pathexpand(local.ssh_key_path))

  controlplanes = [for n in local.inv.nodes : n if n.role == "controlplane"]
  cp            = local.controlplanes[0]

  workers = { for n in local.inv.nodes : n.name => n if n.role == "worker" }

  remote_dir = "/home/${local.ssh_user}/.cache/project-roosevelt"

  kubeconfig_remote_path = "/home/${local.ssh_user}/kubeconfigs/${var.k8s_flavor}-${var.cluster_id}.yaml"
  kubeconfig_local_path  = abspath("${path.module}/kubeconfigs/${var.k8s_flavor}-${var.cluster_id}.yaml")

  # --- Flavor script sources (local) ---
  flavor_dir = "${path.module}/../../../scripts/flavors/${var.k8s_flavor}"

  script_common_prep     = "${path.module}/../../../scripts/common_prep.sh"
  script_kubelet_fix     = "${path.module}/../../../scripts/kubelet_fix.sh"
  script_network_reset   = "${path.module}/../../../scripts/network_reset.sh"
  script_reset           = "${local.flavor_dir}/reset.sh"
  script_install_server  = "${local.flavor_dir}/install_server.sh"
  script_get_kubeconfig  = "${local.flavor_dir}/get_kubeconfig.sh"
  script_get_join        = "${local.flavor_dir}/get_join.sh"
  script_install_agent   = "${local.flavor_dir}/install_agent.sh"
  script_wait_node_ready = "${local.flavor_dir}/wait_node_ready.sh"
}

# -------------------------
# Control plane lifecycle
# -------------------------
resource "null_resource" "controlplane" {
  triggers = {
    cluster_id = var.cluster_id
    flavor     = var.k8s_flavor
    mode       = var.mode

    cp_name = local.cp.name
    cp_host = local.cp.host
    cp_ip   = local.cp.node_ip
  }

  connection {
    type        = "ssh"
    host        = local.cp.host
    user        = local.ssh_user
    private_key = local.ssh_private_key
  }

  provisioner "remote-exec" {
    inline = [
      "set -eu",
      "mkdir -p ${local.remote_dir}",
      "chmod 755 ${local.remote_dir}",
    ]
  }

  # Copy common + flavor scripts
  provisioner "file" {
    source      = local.script_common_prep
    destination = "${local.remote_dir}/common_prep.sh"
  }
  provisioner "file" {
    source      = local.script_kubelet_fix
    destination = "${local.remote_dir}/kubelet_fix.sh"
  }
  provisioner "file" {
    source      = local.script_network_reset
    destination = "${local.remote_dir}/network_reset.sh"
  }
  provisioner "file" {
    source      = local.script_reset
    destination = "${local.remote_dir}/reset.sh"
  }
  provisioner "file" {
    source      = local.script_install_server
    destination = "${local.remote_dir}/install_server.sh"
  }
  provisioner "file" {
    source      = local.script_get_kubeconfig
    destination = "${local.remote_dir}/get_kubeconfig.sh"
  }
  provisioner "file" {
    source      = local.script_get_join
    destination = "${local.remote_dir}/get_join.sh"
  }
  provisioner "file" {
    source      = local.script_wait_node_ready
    destination = "${local.remote_dir}/wait_node_ready.sh"
  }

  provisioner "remote-exec" {
    inline = concat(
      [
        "set -eu",
        "chmod +x ${local.remote_dir}/*.sh",
        "sudo bash ${local.remote_dir}/common_prep.sh",
      ],
      var.mode == "down" ? [
        "sudo bash ${local.remote_dir}/reset.sh",
      ] : [
        "sudo bash ${local.remote_dir}/reset.sh",
        "sudo bash ${local.remote_dir}/install_server.sh '${local.cp.node_ip}'",
        "sudo mkdir -p $(dirname ${local.kubeconfig_remote_path})",
        "sudo bash ${local.remote_dir}/get_kubeconfig.sh '${local.kubeconfig_remote_path}' '${local.ssh_user}' '${local.cp.node_ip}'",
      ]
    )
  }
}

# -------------------------
# Copy kubeconfig back to local (sharin)
# -------------------------
resource "null_resource" "kubeconfig_local" {
  depends_on = [null_resource.controlplane]

  triggers = {
    cluster_id = var.cluster_id
    flavor     = var.k8s_flavor
    mode       = var.mode
    cp_host    = local.cp.host
  }

  provisioner "local-exec" {
    command = var.mode == "down" ? "rm -f '${local.kubeconfig_local_path}' || true" : <<EOT
set -euo pipefail
mkdir -p "$(dirname '${local.kubeconfig_local_path}')"
scp -i '${pathexpand(local.ssh_key_path)}' -o StrictHostKeyChecking=accept-new \
  '${local.ssh_user}@${local.cp.host}:${local.kubeconfig_remote_path}' \
  '${local.kubeconfig_local_path}'
chmod 600 '${local.kubeconfig_local_path}'
EOT
    interpreter = ["/bin/bash", "-lc"]
  }
}

# -------------------------
# Workers lifecycle
# -------------------------
resource "null_resource" "workers" {
  for_each   = local.workers
  depends_on = [null_resource.controlplane]

  triggers = {
    cluster_id = var.cluster_id
    flavor     = var.k8s_flavor
    mode       = var.mode

    name   = each.value.name
    host   = each.value.host
    nodeip = each.value.node_ip
    labels = jsonencode(try(each.value.labels, {}))
  }

  connection {
    type        = "ssh"
    host        = each.value.host
    user        = local.ssh_user
    private_key = local.ssh_private_key
  }

  provisioner "remote-exec" {
    inline = [
      "set -eu",
      "mkdir -p ${local.remote_dir}",
      "chmod 755 ${local.remote_dir}",
    ]
  }

  provisioner "file" {
    source      = local.script_common_prep
    destination = "${local.remote_dir}/common_prep.sh"
  }
  provisioner "file" {
    source      = local.script_kubelet_fix
    destination = "${local.remote_dir}/kubelet_fix.sh"
  }
  provisioner "file" {
    source      = local.script_network_reset
    destination = "${local.remote_dir}/network_reset.sh"
  }
  provisioner "file" {
    source      = local.script_reset
    destination = "${local.remote_dir}/reset.sh"
  }
  provisioner "file" {
    source      = local.script_install_agent
    destination = "${local.remote_dir}/install_agent.sh"
  }

  provisioner "remote-exec" {
    inline = concat(
      [
        "set -eu",
        "chmod +x ${local.remote_dir}/*.sh",
        "sudo bash ${local.remote_dir}/common_prep.sh",
      ],
      var.mode == "down" ? [
        "sudo bash ${local.remote_dir}/reset.sh",
      ] : [
        "sudo bash ${local.remote_dir}/reset.sh",
        "JOIN=$(ssh -i '${pathexpand(local.ssh_key_path)}' -o StrictHostKeyChecking=accept-new '${local.ssh_user}@${local.cp.host}' 'sudo bash ${local.remote_dir}/get_join.sh')",
        "sudo bash ${local.remote_dir}/install_agent.sh '${each.value.node_ip}' '${local.cp.node_ip}' \"$JOIN\"",
        "ssh -i '${pathexpand(local.ssh_key_path)}' -o StrictHostKeyChecking=accept-new '${local.ssh_user}@${local.cp.host}' 'sudo bash ${local.remote_dir}/wait_node_ready.sh ${each.value.node_ip} 300'",
      ]
    )
  }
}