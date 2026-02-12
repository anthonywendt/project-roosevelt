# ==============================================================================
# Flatten Overrides
# Converts path/value pairs to provider format
# - Lists: expanded to indexed paths (path[0], path[1], etc.)
# - Maps/scalars: jsonencode or tostring
# ==============================================================================

locals {
  overrides = { for comp, charts in var.pkg.overrides : comp => {
    for chart, items in charts : chart => flatten([
      for item in items : (
        can(tolist(item.value)) && !can(tostring(item.value)) ? [
          for i, v in item.value : { path = "${item.path}[${i}]", value = try(tostring(v), jsonencode(v)) }
        ] :
        [{ path = item.path, value = try(tostring(item.value), jsonencode(item.value)) }]
      )
    ])
  } }

  sensitive_overrides = { for comp, charts in var.pkg.sensitive_overrides : comp => {
    for chart, items in charts : chart => flatten([
      for item in items : (
        can(tolist(item.value)) && !can(tostring(item.value)) ? [
          for i, v in item.value : { path = "${item.path}[${i}]", value = try(tostring(v), jsonencode(v)) }
        ] :
        [{ path = item.path, value = try(tostring(item.value), jsonencode(item.value)) }]
      )
    ])
  } }
}

resource "uds_package" "this" {
  source = var.pkg.source

  vars = [for k, v in var.pkg.vars : { name = k, value = v }]

  dynamic "component" {
    for_each = local.overrides
    content {
      name = component.key
      dynamic "override" {
        for_each = component.value
        content {
          chart_name = override.key
          values     = override.value
        }
      }
    }
  }

  dynamic "component" {
    for_each = local.sensitive_overrides
    content {
      name = component.key
      dynamic "override" {
        for_each = component.value
        content {
          chart_name       = override.key
          sensitive_values = override.value
        }
      }
    }
  }
}
