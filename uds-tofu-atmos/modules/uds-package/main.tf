locals {
  grouped_package_overrides = {
    for component_name in sort(keys(var.package_overrides_map)) :
    component_name => {
      for chart_name in sort(keys(var.package_overrides_map[component_name])) :
      chart_name => {
        values = [
          for path in sort(keys(try(var.package_overrides_map[component_name][chart_name].values, {}))) : {
            path  = path
            value = var.package_overrides_map[component_name][chart_name].values[path]
          }
        ]
        sensitive_values = [
          for path in sort(keys(try(var.package_overrides_map[component_name][chart_name].sensitive_values, {}))) : {
            path  = path
            value = var.package_overrides_map[component_name][chart_name].sensitive_values[path]
          }
        ]
      }
    }
  }
}

resource "uds_package" "package" {
  source = var.package_requirements.source

  # zarf package variables
  vars = [for k, v in var.package_requirements.package_vars : { name = k, value = v }]

  # zarf Components without overrides used for zarf optional components
  dynamic "component" {
    for_each = lookup(var.package_requirements, "components", [])
    content {
      name = component.value.name
    }
  }

  # Components with overrides
  dynamic "component" {
    for_each = local.grouped_package_overrides
    content {
      name = component.key

      dynamic "override" {
        for_each = component.value
        content {
          chart_name       = override.key
          values           = length(override.value.values) > 0 ? override.value.values : null
          sensitive_values = length(override.value.sensitive_values) > 0 ? override.value.sensitive_values : null
        }
      }
    }
  }
}
