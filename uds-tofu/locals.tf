# ==============================================================================
# Versions
# ==============================================================================
terraform {
  required_providers {
    uds = {
      source = "ghcr.io/defenseunicorns/uds"
      # renovate: datasource=docker depName=ghcr.io/defenseunicorns/uds versioning=semver
      version = ">= 0.1.4"
    }
  }
}

locals {
  architecture = "amd64"
  flavor       = "upstream"
  domain       = "uds.dev"

  # renovate: datasource=github-releases depName=zarf-dev/zarf
  zarf_version = "v0.70.1"
  # renovate: datasource=github-releases depName=defenseunicorns/uds-core extractVersion=^(?<version>.*)-upstream$
  uds_version = "0.60.1-${local.flavor}"
  # renovate: datasource=github-releases depName=defenseunicorns/uds-k3d extractVersion=^(?<version>.*)-airgap$
  uds_k3d_version = "0.19.4-airgap"

  # renovate: datasource=github-releases depName=stefanprodan/podinfo
  podinfo_version = "6.9.4"

  metal_lb_version = "0.15.2-uds.4-upstream"
}

# ==============================================================================
# Package Configurations
# ==============================================================================

locals {
  metal_lb = {
    source = "oci://ghcr.io/uds-packages/metallb:${local.metal_lb_version}"

    vars = {
      IP_ADDRESS_POOL = "192.168.69.200-192.168.69.220"
    }

    overrides = {}
    sensitive_overrides = {}
  }
}

locals {
  uds_k3d = {
    source = "oci://ghcr.io/defenseunicorns/packages/uds-k3d:${local.uds_k3d_version}"

    vars = {
      K3D_EXTRA_ARGS = "--api-port 127.0.0.1:6443 --k3s-arg --kube-apiserver-arg=feature-gates=ImageVolume=true@server:0 --k3s-arg --kubelet-arg=feature-gates=ImageVolume=true@server:0"
    }

    overrides = {
      uds-dev-stack = {
        minio = [
          { path = "buckets", value = ["test-b-1", "test-b-2"] },
          { path = "svcaccts", value = ["test-svcacct-1", "test-svcacct-2"] },
          { path = "users", value = ["test-user-1", "test-user-2"] },
          { path = "policies", value = ["test-policy-1", "test-policy-2"] },
        ]
      }
    }

    sensitive_overrides = {}
  }
}

locals {
  core_base = {
    source = "oci://ghcr.io/defenseunicorns/packages/uds/core-base:${local.uds_version}"

    vars = {
      DOMAIN = local.domain
    }

    overrides = {
      pepr-uds-core = {
        module = [
          { path = "additionalIgnoredNamespaces", value = "- uds-dev-stack\n" },
          { path = "watcher.resources.requests", value = { memory = "64Mi", cpu = "100m" } },
          { path = "admission.resources.requests", value = { memory = "64Mi", cpu = "100m" } },
        ]
      }

      istio-controlplane = {
        istiod = [
          { path = "resources.requests", value = { memory = "1024Mi", cpu = "100m" } },
          { path = "global.proxy.resources.requests", value = { memory = "40Mi", cpu = "10m" } },
          { path = "global.proxy.resources.limits", value = { memory = "1024Mi", cpu = "2000m" } },
        ]
      }
    }

    sensitive_overrides = {}
  }
}

locals {
  core_logging = {
    source = "oci://ghcr.io/defenseunicorns/packages/uds/core-logging:${local.uds_version}"

    vars = {}

    overrides = {
      loki = {
        loki = [
          { path = "write.replicas", value = 1 },
          { path = "read.replicas", value = 1 },
          { path = "backend.replicas", value = 1 },
        ]
      }
    }

    sensitive_overrides = {}
  }
}

locals {
  core_monitoring = {
    source              = "oci://ghcr.io/defenseunicorns/packages/uds/core-monitoring:${local.uds_version}"
    vars                = {}
    overrides           = {}
    sensitive_overrides = {}
  }
}

locals {
  core_backup_restore = {
    source              = "oci://ghcr.io/defenseunicorns/packages/uds/core-backup-restore:${local.uds_version}"
    vars                = {}
    overrides           = {}
    sensitive_overrides = {}
  }
}

locals {
  core_identity_authorization = {
    source = "oci://ghcr.io/defenseunicorns/packages/uds/core-identity-authorization:${local.uds_version}"

    vars = {
      DOMAIN = local.domain
    }

    overrides = {
      authservice = {
        authservice = [
          { path = "replicaCount", value = 1 },
        ]
      }

      keycloak = {
        keycloak = [
          { path = "devMode", value = true },
          { path = "resources.requests", value = { memory = "512Mi", cpu = "100m" } },
          { path = "resources.limits", value = { memory = "1Gi", cpu = "1000m" } },
          { path = "waypoint.horizontalPodAutoscaler.enabled", value = false },
          { path = "waypoint.deployment.requests", value = { cpu = "100m", memory = "64Mi" } },
          { path = "realmInitEnv.GOOGLE_IDP_ENABLED", value = true },
          { path = "realmInitEnv.GOOGLE_IDP_ID", value = "C01881u7t" },
          { path = "realmInitEnv.GOOGLE_IDP_SIGNING_CERT", value = "MIIDdDCCAlygAwIBAgIGAXkza8/+MA0GCSqGSIb3DQEBCwUAMHsxFDASBgNVBAoTC0dvb2dsZSBJbmMuMRYwFAYDVQQHEw1Nb3VudGFpbiBWaWV3MQ8wDQYDVQQDEwZHb29nbGUxGDAWBgNVBAsTD0dvb2dsZSBGb3IgV29yazELMAkGA1UEBhMCVVMxEzARBgNVBAgTCkNhbGlmb3JuaWEwHhcNMjEwNTAzMTgwOTMzWhcNMjYwNTAyMTgwOTMzWjB7MRQwEgYDVQQKEwtHb29nbGUgSW5jLjEWMBQGA1UEBxMNTW91bnRhaW4gVmlldzEPMA0GA1UEAxMGR29vZ2xlMRgwFgYDVQQLEw9Hb29nbGUgRm9yIFdvcmsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpDYWxpZm9ybmlhMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAu9en1CO4EriCJ5jzss6TqUmtYMXXRBfsSkdnhVvMx0fYOegxy0d8DouUEEITlPW+YPBG1T72kiV9KGtKVw90ff4Y+siNDNrME81w4K3Zjo6VukvATfD05lVzh9JyO0VxdzBpdRXSJqBOVLo38cwVbyTcX5Nk/nHENjDSN7as3UvbXa7eT4Xswy1GARGAZ3MAaLTZn1+Cctn0MDKniQOS6QDryYgKWz8ko/H4T9XCxgjHJVsL6obezaPZF+pibyyVPCuePssuxUbFHF6yiP5rCfAsK6VTv/8pbYGauGpYHDgnM941RtN2ThltORgi+P9i9wQ8VRBQpEm1RvDXOqJ7OwIDAQABMA0GCSqGSIb3DQEBCwUAA4IBAQB5L26tpco6EgVunmZYBAFiFE+Dhqwvy4J1iKuXApaKhqabeKJ8kBv/pJBnZl7CRF5Pv8dLfhNoNm2BsXbpH91/rhDj9zl/Imkc5ttVGbXbKSBpUaduwBZpsVIX0xCugNPflHFz9kf/zsGWb3X6wO/2eNewj3fr8jNRC/KWQ7otcdqwYbe1BO4yo6FjAIs5L+wCQcc2JjRWgBon4wL25ccX3nH8aMHl4/gz5trKwPqH0/lYcScJmMSRPzHbmd62LlmZE9eWEwuYJ+h8fssTZA9JTMXvkPhg05w2snaM9XdSuXIRo4UtqGpMQC0KRMmwDHbVSluX63wn7iSZD4TGHZGa" },
          { path = "realmInitEnv.GOOGLE_IDP_NAME_ID_FORMAT", value = "urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified" },
          { path = "realmInitEnv.GOOGLE_IDP_CORE_ENTITY_ID", value = "https://sso.uds.dev/realms/uds" },
          { path = "realmInitEnv.GOOGLE_IDP_ADMIN_GROUP", value = "uds-core-dev-admin" },
          { path = "realmInitEnv.GOOGLE_IDP_AUDITOR_GROUP", value = "uds-core-dev-auditor" },
          { path = "env", value = "- name: JAVA_OPTS_KC_HEAP\n  value: \"-XX:MaxRAMPercentage=70 -XX:MinRAMPercentage=70 -XX:InitialRAMPercentage=50 -XX:MaxRAM=1G\"\n" },
        ]
      }
    }

    sensitive_overrides = {}
  }
}

locals {
  podinfo = {
    source = "packages/podinfo/zarf-package-podinfo-${local.architecture}-${local.podinfo_version}.tar.zst"

    vars = {
      ENV = "dev"
    }

    overrides = {
      podinfo = {
        podinfo = [
          { path = "replicaCount", value = 3 },
        ]
      }
    }

    sensitive_overrides = {}
  }
}
