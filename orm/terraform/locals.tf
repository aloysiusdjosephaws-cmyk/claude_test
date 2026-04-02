resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  # ── Naming ─────────────────────────────────────────────────────────────────
  app       = lower(var.app_name)
  suffix    = random_id.suffix.hex
  prefix    = "${local.app}-${local.suffix}"

  # ── Tenancy / OCIR ─────────────────────────────────────────────────────────
  tenancy_namespace    = data.oci_objectstorage_namespace.tenancy.namespace
  ocir_server          = "${var.region}.ocir.io"
  backend_image_repo   = "${local.ocir_server}/${local.tenancy_namespace}/${local.app}-backend"
  frontend_image_repo  = "${local.ocir_server}/${local.tenancy_namespace}/${local.app}-frontend"

  # ── API Gateway ─────────────────────────────────────────────────────────────
  # The gateway hostname is a Terraform output of oci_apigateway_gateway.main.
  # The deployment path prefix /v1 is appended by the gateway deployment resource.
  api_gateway_base_url = "https://${oci_apigateway_gateway.main.hostname}/v1"

  # ── Object Storage buckets ─────────────────────────────────────────────────
  source_bucket_name   = "${local.prefix}-src"     # temporary: holds app source zip
  frontend_bucket_name = "${local.prefix}-fe"      # permanent: hosts Angular static files

  # ── DevOps git HTTPS URL ────────────────────────────────────────────────────
  devops_repo_https_url = "https://devops.scmservice.${var.region}.oci.oraclecloud.com/namespaces/${local.tenancy_namespace}/projects/${oci_devops_project.main.name}/repositories/${oci_devops_repository.buildspecs.name}"

  # ── Common freeform tags ────────────────────────────────────────────────────
  common_tags = {
    Project     = local.app
    ManagedBy   = "OCI-ResourceManager-Terraform"
  }
}
