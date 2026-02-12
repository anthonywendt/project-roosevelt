variable "pkg" {
  description = "Package configuration"
  type = object({
    source              = string
    vars                = map(string)
    overrides           = any # component -> chart -> values (nested maps from yamldecode)
    sensitive_overrides = any
  })
}
