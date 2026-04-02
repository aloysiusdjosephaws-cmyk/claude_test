# ─── API Gateway ─────────────────────────────────────────────────────────────
# The gateway resource (hostname known immediately after creation).
# The deployment (routes) is created by the build_deploy.tf null_resource
# AFTER the OKE LoadBalancer IP is known.

resource "oci_apigateway_gateway" "main" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.prefix}-apigw"
  endpoint_type  = "PUBLIC"
  subnet_id      = oci_core_subnet.public.id
  freeform_tags  = local.common_tags
}

# NOTE: The oci_apigateway_deployment resource is NOT created here via Terraform
# because the backend LoadBalancer IP is only known after Helm deploys the K8s
# service. Instead, build_deploy.tf uses a null_resource with OCI CLI to create
# the deployment once the LB IP is available.
