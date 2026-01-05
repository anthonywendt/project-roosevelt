output "kubeconfig_path" {
  description = "Local kubeconfig path on the machine running tofu (sharin)."
  value       = local.kubeconfig_local_path
  depends_on  = [null_resource.kubeconfig_local]
}
