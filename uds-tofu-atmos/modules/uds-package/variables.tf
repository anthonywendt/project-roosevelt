variable "package_requirements" {
  description = "Package requirements including source and optional components"
  type = object({
    source     = string # OCI URL, local file path, or directory path
    package_vars = map(string)
    components = optional(list(object({
      name = string
    })), [])
  })
}

variable "package_overrides" {
  description = "Package overrides for components, charts, and values"
  type = list(object({
    component_name = string
    chart_name     = optional(string)
    values = optional(list(object({
      path  = string
      value = any
    })), [])
    sensitive_values = optional(list(object({
      path  = string
      value = any
    })), [])
  }))
  default = []
}
