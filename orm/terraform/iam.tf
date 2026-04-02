# ─── Dynamic Groups ───────────────────────────────────────────────────────────
# Dynamic groups are tenancy-level resources. The user running this stack must
# have tenancy-level IAM admin permissions (or the stack service account must).

# Dynamic group: OCI DevOps build runner instances
resource "oci_identity_dynamic_group" "devops_build_runners" {
  compartment_id = var.tenancy_ocid
  name           = "${local.prefix}-devops-build-runners"
  description    = "Managed build runner instances for OCI DevOps project ${local.app}"
  matching_rule  = "All {resource.type = 'devopsbuildbpipelinerunner', resource.compartment.id = '${var.compartment_ocid}'}"
  freeform_tags  = local.common_tags
}

# Dynamic group: OCI DevOps pipelines (for deployment)
resource "oci_identity_dynamic_group" "devops_pipelines" {
  compartment_id = var.tenancy_ocid
  name           = "${local.prefix}-devops-pipelines"
  description    = "OCI DevOps pipeline resources for project ${local.app}"
  matching_rule  = "All {resource.type = 'devopsdeploypipeline', resource.compartment.id = '${var.compartment_ocid}'}"
  freeform_tags  = local.common_tags
}

# Dynamic group: OKE worker nodes (to pull images from OCIR without a pull secret)
resource "oci_identity_dynamic_group" "oke_nodes" {
  compartment_id = var.tenancy_ocid
  name           = "${local.prefix}-oke-nodes"
  description    = "OKE worker nodes for cluster ${local.app}"
  matching_rule  = "All {resource.type = 'instance', resource.compartment.id = '${var.compartment_ocid}'}"
  freeform_tags  = local.common_tags
}

# ─── Policies ────────────────────────────────────────────────────────────────

# Policy: DevOps build runners — ability to push images, read source from Object Storage
resource "oci_identity_policy" "devops_build" {
  compartment_id = var.tenancy_ocid
  name           = "${local.prefix}-devops-build-policy"
  description    = "Allows DevOps build runners to push images to OCIR and read source from Object Storage"
  freeform_tags  = local.common_tags

  statements = [
    # Push images to OCIR
    "Allow dynamic-group ${oci_identity_dynamic_group.devops_build_runners.name} to manage repos in compartment id ${var.compartment_ocid}",
    # Read app source zip from Object Storage
    "Allow dynamic-group ${oci_identity_dynamic_group.devops_build_runners.name} to read objects in compartment id ${var.compartment_ocid}",
    # Write frontend build output to Object Storage
    "Allow dynamic-group ${oci_identity_dynamic_group.devops_build_runners.name} to manage objects in compartment id ${var.compartment_ocid}",
    # Log build output
    "Allow dynamic-group ${oci_identity_dynamic_group.devops_build_runners.name} to use log-content in compartment id ${var.compartment_ocid}",
  ]
}

# Policy: OKE nodes — pull images from OCIR
resource "oci_identity_policy" "oke_ocir_pull" {
  compartment_id = var.tenancy_ocid
  name           = "${local.prefix}-oke-ocir-pull-policy"
  description    = "Allows OKE worker nodes to pull images from OCIR"
  freeform_tags  = local.common_tags

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.oke_nodes.name} to read repos in compartment id ${var.compartment_ocid}",
  ]
}

# Policy: DevOps service — manage resources in the compartment
resource "oci_identity_policy" "devops_service" {
  compartment_id = var.compartment_ocid
  name           = "${local.prefix}-devops-svc-policy"
  description    = "Allows OCI DevOps service to manage resources"
  freeform_tags  = local.common_tags

  statements = [
    "Allow service devops to manage all-resources in compartment id ${var.compartment_ocid}",
  ]
}
