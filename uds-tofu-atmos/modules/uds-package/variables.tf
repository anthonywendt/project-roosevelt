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

variable "package_overrides_map" {
  description = "Preferred package overrides keyed by component, chart, and path"
  type = map(map(object({
    values           = optional(map(any), {})
    sensitive_values = optional(map(any), {})
  })))
  default = {}
}