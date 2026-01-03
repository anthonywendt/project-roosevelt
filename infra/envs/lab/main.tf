locals {
  inventory_path = abspath("${path.module}/../../../${var.inventory_file}")
  inv            = yamldecode(file(local.inventory_path))
  ssh_user       = local.inv.ssh_user

  controlplanes = [for n in local.inv.nodes : n if n.role == "controlplane"]
  cp            = local.controlplanes[0]

  host    = local.cp.host
  node_ip = local.cp.node_ip

  remote_dir = "/home/${local.ssh_user}/.cache/project-roosevelt"
  kubeconfig_path = "/home/${local.ssh_user}/kubeconfigs/${var.k8s_flavor}-${var.cluster_id}.yaml"
}

resource "null_resource" "lifecycle" {
  triggers = {
    cluster_id = var.cluster_id
    flavor     = var.k8s_flavor
    mode       = var.mode
    node_ip    = local.node_ip
  }

  # 1) ensure staging dir exists (non-root path)
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = local.host
      user        = local.ssh_user
      private_key = file(pathexpand("~/.ssh/project_roosevelt_ed25519"))
    }

    inline = [
      "set -eu",
      "mkdir -p ${local.remote_dir}",
      "chmod 755 ${local.remote_dir}",
    ]
  }

  # 2) copy scripts
  provisioner "file" {
    connection {
      type        = "ssh"
      host        = local.host
      user        = local.ssh_user
      private_key = file(pathexpand("~/.ssh/project_roosevelt_ed25519"))
    }

    source      = "${path.module}/../../../scripts/common_prep.sh"
    destination = "${local.remote_dir}/common_prep.sh"
  }

  provisioner "file" {
    connection {
      type        = "ssh"
      host        = local.host
      user        = local.ssh_user
      private_key = file(pathexpand("~/.ssh/project_roosevelt_ed25519"))
    }

    source      = "${path.module}/../../../scripts/k3s_reset.sh"
    destination = "${local.remote_dir}/k3s_reset.sh"
  }

  provisioner "file" {
    connection {
      type        = "ssh"
      host        = local.host
      user        = local.ssh_user
      private_key = file(pathexpand("~/.ssh/project_roosevelt_ed25519"))
    }

    source      = "${path.module}/../../../scripts/k3s_install_server.sh"
    destination = "${local.remote_dir}/k3s_install_server.sh"
  }

  # 3) run scripts
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = local.host
      user        = local.ssh_user
      private_key = file(pathexpand("~/.ssh/project_roosevelt_ed25519"))
    }

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
          "sudo mkdir -p $(dirname ${local.kubeconfig_path})",
          "sudo bash ${local.remote_dir}/k3s_install_server.sh '${local.node_ip}' '${local.kubeconfig_path}' '${local.ssh_user}'",
        ]
      ) : [
        "echo 'Unsupported flavor for Day 1: ${var.k8s_flavor}'",
        "exit 1",
      ]
    )
  }
}
