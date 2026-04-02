# ─── Source code bucket (temporary) ─────────────────────────────────────────
# Holds the app source zip that DevOps build pipelines download.
# Can be deleted after the first successful build.

resource "oci_objectstorage_bucket" "source_code" {
  compartment_id = var.compartment_ocid
  namespace      = local.tenancy_namespace
  name           = local.source_bucket_name
  access_type    = "NoPublicAccess"
  freeform_tags  = local.common_tags
}

# ─── App source archive ───────────────────────────────────────────────────────
# archive_file data source is evaluated during Terraform apply within ORM.
# ORM extracts the full bundle zip first, so path.module/app/ is accessible.

data "archive_file" "app_source" {
  type        = "zip"
  source_dir  = "${path.module}/app"
  output_path = "${path.module}/app_source.zip"
}

# Upload the app source zip directly via the OCI Terraform provider — no shell needed.
resource "oci_objectstorage_object" "app_source" {
  namespace    = local.tenancy_namespace
  bucket       = oci_objectstorage_bucket.source_code.name
  object       = "app_source.zip"
  source       = data.archive_file.app_source.output_path
  content_type = "application/zip"
}

# ─── Frontend static bucket (permanent) ─────────────────────────────────────
# Hosts the Angular production build output as a static website.

resource "oci_objectstorage_bucket" "frontend" {
  compartment_id = var.compartment_ocid
  namespace      = local.tenancy_namespace
  name           = local.frontend_bucket_name
  access_type    = "ObjectRead"   # Public read — required for a static website
  freeform_tags  = local.common_tags
}
