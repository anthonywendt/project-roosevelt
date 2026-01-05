locals {
  inventory_path = abspath("${path.module}/../../../${var.inventory_file}")
  inv            = yamldecode(file(local.inventory_path))

  ssh_user = local.inv.ssh_user

  # Keep your existing key convention
  ssh_key_path    = "~/.ssh/project_roosevelt_ed25519"
  ssh_private_key = file(pathexpand(local.ssh_key_path))

  # Select nodes by role
  controlplanes = [for n in local.inv.nodes : n if n.role == "controlplane"]
  cp            = local.controlplanes[0]

  # Workers map for for_each (must be a map, not a list)
  workers = { for n in local.inv.nodes : n.name => n if n.role == "worker" }

  remote_dir = "/home/${local.ssh_user}/.cache/project-roosevelt"

  # kubeconfig path ON the control plane node
  kubeconfig_remote_path = "/home/${local.ssh_user}/kubeconfigs/${var.k8s_flavor}-${var.cluster_id}.yaml"

  # kubeconfig path ON the machine running tofu (sharin)
  kubeconfig_local_path = "${path.module}/kubeconfigs/${var.k8s_flavor}-${var.cluster_id}.yaml"
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

  # 1) ensure staging dir exists (non-root path)
  provisioner "remote-exec" {
    inline = [
      "set -eu",
      "mkdir -p ${local.remote_dir}",
      "chmod 755 ${local.remote_dir}",
    ]
  }

  # 2) copy scripts
  provisioner "file" {
    source      = "${path.module}/../../../scripts/common_prep.sh"
    destination = "${local.remote_dir}/common_prep.sh"
  }

  provisioner "file" {
    source      = "${path.module}/../../../scripts/k3s_reset.sh"
    destination = "${local.remote_dir}/k3s_reset.sh"
  }

  provisioner "file" {
    source      = "${path.module}/../../../scripts/k3s_install_server.sh"
    destination = "${local.remote_dir}/k3s_install_server.sh"
  }

  # 3) run scripts
  provisioner "remote-exec" {
    inline = concat(
      [
        "set -eu",
        "chmod +x ${local.remote_dir}/*.sh",
        "sudo bash ${local.remote_dir}/common_prep.sh",
      ],
      var.k8s_flavor == "k3s" ? (
        var.mode == "down" ? [
          "sudo bash ${local.remote_dir}/k3s_reset.sh",
        ] : [
          "sudo bash ${local.remote_dir}/k3s_reset.sh",
          "sudo mkdir -p $(dirname ${local.kubeconfig_remote_path})",
          "sudo bash ${local.remote_dir}/k3s_install_server.sh '${local.cp.node_ip}' '${local.kubeconfig_remote_path}' '${local.ssh_user}'",
        ]
      ) : [
        "echo 'Unsupported flavor for Day 1: ${var.k8s_flavor}'",
        "exit 1",
      ]
    )
  }
}

# -------------------------
# Copy kubeconfig back to sharin
# (so lab:status works locally even when CP is remote)
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
# Workers (join/leave)
# Token is fetched at runtime (apply-time) to avoid plan-time file() issues
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
    source      = "${path.module}/../../../scripts/common_prep.sh"
    destination = "${local.remote_dir}/common_prep.sh"
  }

  provisioner "file" {
    source      = "${path.module}/../../../scripts/k3s_reset.sh"
    destination = "${local.remote_dir}/k3s_reset.sh"
  }

  provisioner "file" {
    source      = "${path.module}/../../../scripts/k3s_install_agent.sh"
    destination = "${local.remote_dir}/k3s_install_agent.sh"
  }

  provisioner "remote-exec" {
    inline = concat(
      [
        "set -eu",
        "chmod +x ${local.remote_dir}/*.sh",
        "sudo bash ${local.remote_dir}/common_prep.sh",
      ],
      var.k8s_flavor == "k3s" ? (
        var.mode == "down" ? [
          "sudo bash ${local.remote_dir}/k3s_reset.sh",
        ] : [
          "sudo bash ${local.remote_dir}/k3s_reset.sh",

          # Fetch token from the control plane at apply-time
          "TOKEN=$(ssh -i '${pathexpand(local.ssh_key_path)}' -o StrictHostKeyChecking=accept-new '${local.ssh_user}@${local.cp.host}' 'sudo cat /var/lib/rancher/k3s/server/node-token')",

          # Join as agent
          "sudo bash ${local.remote_dir}/k3s_install_agent.sh '${each.value.node_ip}' '${local.cp.node_ip}' \"$TOKEN\"",
        ]
      ) : [
        "echo 'Unsupported flavor for workers Day 1: ${var.k8s_flavor}'",
        "exit 1",
      ]
    )
  }
}