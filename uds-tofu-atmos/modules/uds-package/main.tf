locals {
  # this logic allows for multiple overrides for the same component to be specified in the package_overrides variable, 
  # and will merge them together with the correct precedence (last override specified wins)
  grouped_package_overrides = {
    for component_name, overrides in { for override in var.package_overrides : override.component_name => override... } :
    component_name => {
      chart_name = try(
        [for override in reverse(overrides) : override.chart_name if try(override.chart_name, null) != null][0],
        null,
      )
      values = [
        for path in distinct([for value_item in flatten([
          for override in overrides : try(override.values, [])
          ]) : value_item.path]) : merge([
          for value_item in flatten([
            for override in overrides : try(override.values, [])
          ]) : { (value_item.path) = value_item }
        ]...)[path]
      ]
      sensitive_values = [
        for path in distinct([for value_item in flatten([
          for override in overrides : try(override.sensitive_values, [])
          ]) : value_item.path]) : merge([
          for value_item in flatten([
            for override in overrides : try(override.sensitive_values, [])
          ]) : { (value_item.path) = value_item }
        ]...)[path]
      ]
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

  # zarf Components with overrides
  dynamic "component" {
    for_each = local.grouped_package_overrides
    content {
      name = component.key

      dynamic "override" {
        for_each = component.value.chart_name != null ? [component.value] : []
        content {
          chart_name       = override.value.chart_name
          values           = override.value.values
          sensitive_values = length(override.value.sensitive_values) > 0 ? override.value.sensitive_values : null
        }
      }
    }
  }
}
