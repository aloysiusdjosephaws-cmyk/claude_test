# ─────────────────────────────────────────────────────────────────────────────
# build_deploy.tf
#
# Orchestrates all post-infrastructure steps using null_resource local-exec:
#   1. Push build spec files to DevOps Code Repository (git)
#   2. Trigger backend Docker build pipeline → wait for completion
#   3. Trigger frontend Angular build pipeline → wait for completion
#      (frontend pipeline also uploads built files to Object Storage)
#   4. Wait for OKE cluster to be ACTIVE
#   5. Configure kubectl
#   6. Create OCIR image pull secret in Kubernetes
#   7. Helm deploy the backend to OKE
#   8. Wait for the OCI LoadBalancer IP to be assigned
#   9. Create OCI API Gateway deployment with backend routes
# ─────────────────────────────────────────────────────────────────────────────

# ── Step 1: Push build specs to DevOps Code Repository ───────────────────────

resource "null_resource" "push_buildspecs" {
  # Re-run whenever build spec files change or the repo changes
  triggers = {
    repo_id               = oci_devops_repository.buildspecs.id
    backend_spec_hash     = filemd5("${path.module}/build_specs/backend_build_spec.yaml")
    frontend_spec_hash    = filemd5("${path.module}/build_specs/frontend_build_spec.yaml")
  }

  depends_on = [
    oci_devops_repository.buildspecs,
    oci_devops_build_pipeline_stage.backend_build,
    oci_devops_build_pipeline_stage.frontend_build,
    oci_identity_policy.devops_build,
    oci_identity_policy.devops_service,
  ]

  provisioner "local-exec" {
    command     = "bash ${path.module}/scripts/push_buildspecs.sh"
    interpreter = ["bash", "-c"]
    environment = {
      REPO_HTTPS_URL  = local.devops_repo_https_url
      GIT_USERNAME    = var.devops_git_username
      AUTH_TOKEN      = var.auth_token
      SPECS_DIR       = "${path.module}/build_specs"
    }
  }
}

# ── Step 2: Trigger backend build pipeline ────────────────────────────────────

resource "null_resource" "trigger_backend_build" {
  triggers = {
    app_source_etag = oci_objectstorage_object.app_source.etag
    build_spec_hash = filemd5("${path.module}/build_specs/backend_build_spec.yaml")
  }

  depends_on = [
    null_resource.push_buildspecs,
    oci_objectstorage_object.app_source,
    oci_artifacts_container_repository.backend,
  ]

  provisioner "local-exec" {
    command     = "bash ${path.module}/scripts/trigger_build.sh"
    interpreter = ["bash", "-c"]
    environment = {
      PIPELINE_ID       = oci_devops_build_pipeline.backend.id
      REGION            = var.region
      COMPARTMENT_OCID  = var.compartment_ocid
      TENANCY_NAMESPACE = local.tenancy_namespace
      SOURCE_BUCKET     = local.source_bucket_name
      IMAGE_REPO        = local.backend_image_repo
      IMAGE_TAG         = var.image_tag
      DEVOPS_GIT_USERNAME = var.devops_git_username
      AUTH_TOKEN        = var.auth_token
      PIPELINE_TYPE     = "backend"
    }
  }
}

# ── Step 3: Trigger frontend build pipeline ───────────────────────────────────
# Depends on the API Gateway being created so we know the hostname for Angular.

resource "null_resource" "trigger_frontend_build" {
  triggers = {
    app_source_etag   = oci_objectstorage_object.app_source.etag
    build_spec_hash   = filemd5("${path.module}/build_specs/frontend_build_spec.yaml")
    api_gateway_url   = local.api_gateway_base_url
  }

  depends_on = [
    null_resource.push_buildspecs,
    oci_objectstorage_object.app_source,
    oci_artifacts_container_repository.frontend,
    oci_apigateway_gateway.main,
    oci_objectstorage_bucket.frontend,
  ]

  provisioner "local-exec" {
    command     = "bash ${path.module}/scripts/trigger_build.sh"
    interpreter = ["bash", "-c"]
    environment = {
      PIPELINE_ID       = oci_devops_build_pipeline.frontend.id
      REGION            = var.region
      COMPARTMENT_OCID  = var.compartment_ocid
      TENANCY_NAMESPACE = local.tenancy_namespace
      SOURCE_BUCKET     = local.source_bucket_name
      IMAGE_REPO        = local.frontend_image_repo
      IMAGE_TAG         = var.image_tag
      DEVOPS_GIT_USERNAME = var.devops_git_username
      AUTH_TOKEN        = var.auth_token
      API_GATEWAY_URL   = local.api_gateway_base_url
      FRONTEND_BUCKET   = local.frontend_bucket_name
      PIPELINE_TYPE     = "frontend"
    }
  }
}

# ── Step 4-6: Configure kubectl + create OCIR pull secret ────────────────────

resource "null_resource" "configure_kubectl" {
  triggers = {
    cluster_id = oci_containerengine_cluster.main.id
  }

  depends_on = [
    oci_containerengine_node_pool.main,
  ]

  provisioner "local-exec" {
    command     = "bash ${path.module}/scripts/setup_kubeconfig.sh"
    interpreter = ["bash", "-c"]
    environment = {
      CLUSTER_ID  = oci_containerengine_cluster.main.id
      REGION      = var.region
    }
  }
}

resource "null_resource" "create_ocir_secret" {
  triggers = {
    cluster_id = oci_containerengine_cluster.main.id
  }

  depends_on = [
    null_resource.configure_kubectl,
  ]

  provisioner "local-exec" {
    command     = "bash ${path.module}/scripts/create_ocir_secret.sh"
    interpreter = ["bash", "-c"]
    environment = {
      OCIR_SERVER       = local.ocir_server
      DEVOPS_GIT_USERNAME = var.devops_git_username
      AUTH_TOKEN        = var.auth_token
      TENANCY_NAMESPACE = local.tenancy_namespace
    }
  }
}

# ── Step 7: Helm deploy backend ───────────────────────────────────────────────

resource "null_resource" "helm_deploy" {
  triggers = {
    backend_build_trigger  = null_resource.trigger_backend_build.id
    ocir_secret_trigger    = null_resource.create_ocir_secret.id
    backend_image_repo     = local.backend_image_repo
    image_tag              = var.image_tag
  }

  depends_on = [
    null_resource.trigger_backend_build,
    null_resource.create_ocir_secret,
  ]

  provisioner "local-exec" {
    command     = "bash ${path.module}/scripts/helm_deploy.sh"
    interpreter = ["bash", "-c"]
    environment = {
      HELM_CHART_DIR      = "${path.module}/helm/fullstack-app"
      RELEASE_NAME        = local.app
      BACKEND_IMAGE_REPO  = local.backend_image_repo
      FRONTEND_IMAGE_REPO = local.frontend_image_repo
      IMAGE_TAG           = var.image_tag
      TENANCY_NAMESPACE   = local.tenancy_namespace
      REGION              = var.region
      OCIR_SERVER         = local.ocir_server
    }
  }
}

# ── Steps 8-9: Wait for LB IP → Create API Gateway deployment ────────────────

resource "null_resource" "create_api_gateway_deployment" {
  triggers = {
    helm_deploy_id    = null_resource.helm_deploy.id
    gateway_id        = oci_apigateway_gateway.main.id
  }

  depends_on = [
    null_resource.helm_deploy,
    oci_apigateway_gateway.main,
  ]

  provisioner "local-exec" {
    command     = "bash ${path.module}/scripts/create_api_gw_deployment.sh"
    interpreter = ["bash", "-c"]
    environment = {
      GATEWAY_ID        = oci_apigateway_gateway.main.id
      COMPARTMENT_OCID  = var.compartment_ocid
      RELEASE_NAME      = local.app
      APP_NAME          = local.app
      REGION            = var.region
      FRONTEND_BUCKET   = local.frontend_bucket_name
      TENANCY_NAMESPACE = local.tenancy_namespace
    }
  }
}
