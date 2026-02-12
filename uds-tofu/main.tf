provider "uds" {
  default_architecture = local.architecture
}

# ==============================================================================
# UDS Packages
# ==============================================================================

# module "uds_k3d" {
#   source = "./modules/uds-package"
#   pkg    = local.uds_k3d
# }

resource "uds_package" "init" {
  source     = "oci://ghcr.io/zarf-dev/packages/init:${local.zarf_version}"

  # Install optional git-server
  component {
    name = "git-server"
  }
}

module "metal_lb" {
  source     = "./modules/uds-package"
  depends_on = [uds_package.init]
  pkg        = local.metal_lb
}

module "core_base" {
  source     = "./modules/uds-package"
  depends_on = [module.metal_lb]
  pkg        = local.core_base
}

module "core_logging" {
  source     = "./modules/uds-package"
  depends_on = [module.core_base]
  pkg        = local.core_logging
}

module "core_identity_authorization" {
  source     = "./modules/uds-package"
  depends_on = [module.core_base]
  pkg        = local.core_identity_authorization
}

module "core_monitoring" {
  source     = "./modules/uds-package"
  depends_on = [module.core_identity_authorization]
  pkg        = local.core_monitoring
}
