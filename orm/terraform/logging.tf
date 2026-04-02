# OCI Logging is required by OCI DevOps — the DevOps project must have a log group.

resource "oci_logging_log_group" "main" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.prefix}-log-group"
  description    = "Log group for ${local.app} DevOps pipelines"
  freeform_tags  = local.common_tags
}

resource "oci_logging_log" "build" {
  display_name = "${local.prefix}-build-log"
  log_group_id = oci_logging_log_group.main.id
  log_type     = "SERVICE"
  freeform_tags = local.common_tags

  configuration {
    source {
      category    = "all"
      resource    = oci_devops_project.main.id
      service     = "devops"
      source_type = "OCISERVICE"
    }
    compartment_id = var.compartment_ocid
  }

  is_enabled         = true
  retention_duration = 30
}
