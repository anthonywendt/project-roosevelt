variable "k8s_flavor" { type = string }
variable "cluster_id" { type = string }
variable "inventory_file" { type = string }

variable "mode" {
  type    = string
  default = "up"
  validation {
    condition     = contains(["up", "down"], var.mode)
    error_message = "mode must be up or down"
  }
}
