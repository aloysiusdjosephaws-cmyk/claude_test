# OCI Container Registry (OCIR) — private repositories for backend and frontend images

resource "oci_artifacts_container_repository" "backend" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.app}-backend"
  is_public      = false
  freeform_tags  = local.common_tags
}

resource "oci_artifacts_container_repository" "frontend" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.app}-frontend"
  is_public      = false
  freeform_tags  = local.common_tags
}
