# ─── OCI DevOps Project ───────────────────────────────────────────────────────

resource "oci_devops_project" "main" {
  compartment_id = var.compartment_ocid
  name           = "${local.prefix}-devops"
  description    = "CI/CD for ${local.app} file service"
  freeform_tags  = local.common_tags

  notification_config {
    topic_id = oci_ons_notification_topic.devops.id
  }
}

# Notification topic required by DevOps project
resource "oci_ons_notification_topic" "devops" {
  compartment_id = var.compartment_ocid
  name           = "${local.prefix}-devops-topic"
  freeform_tags  = local.common_tags
}

# ─── DevOps Code Repository ───────────────────────────────────────────────────
# Stores the build spec YAML files. The ORM null_resource pushes them via git.

resource "oci_devops_repository" "buildspecs" {
  project_id      = oci_devops_project.main.id
  name            = "build-specs"
  repository_type = "HOSTED"
  description     = "Build specification files for ${local.app}"
  freeform_tags   = local.common_tags
}

# ─── Backend Build Pipeline ───────────────────────────────────────────────────

resource "oci_devops_build_pipeline" "backend" {
  project_id    = oci_devops_project.main.id
  display_name  = "${local.prefix}-build-backend"
  description   = "Builds Spring Boot backend Docker image and pushes to OCIR"
  freeform_tags = local.common_tags

  build_pipeline_parameters {
    items {
      name          = "REGION"
      default_value = var.region
      description   = "OCI region"
    }
    items {
      name          = "TENANCY_NAMESPACE"
      default_value = local.tenancy_namespace
      description   = "OCI tenancy namespace"
    }
    items {
      name          = "BACKEND_IMAGE_REPO"
      default_value = local.backend_image_repo
      description   = "OCIR repository path for backend image"
    }
    items {
      name          = "IMAGE_TAG"
      default_value = var.image_tag
      description   = "Docker image tag"
    }
    items {
      name          = "SOURCE_BUCKET"
      default_value = local.source_bucket_name
      description   = "Object Storage bucket holding app_source.zip"
    }
    items {
      name          = "DEVOPS_GIT_USERNAME"
      default_value = var.devops_git_username
      description   = "OCIR docker login username"
    }
    items {
      name          = "AUTH_TOKEN"
      default_value = "REPLACE_AT_RUNTIME"
      description   = "OCI Auth Token (overridden at trigger time)"
    }
  }
}

resource "oci_devops_build_pipeline_stage" "backend_build" {
  build_pipeline_id = oci_devops_build_pipeline.backend.id
  display_name      = "build-and-push-backend"
  stage_type        = "BUILD"
  description       = "Build Spring Boot Docker image and push to OCIR"
  freeform_tags     = local.common_tags

  build_spec_file   = "build_specs/backend_build_spec.yaml"
  image             = "OL7_X86_64"

  build_pipeline_stage_predecessor_collection {
    items {
      id = oci_devops_build_pipeline.backend.id
    }
  }

  primary_build_source {
    connection_type = "DEVOPS_CODE_REPOSITORY"
    name            = "buildspecs-repo"
    repository_id   = oci_devops_repository.buildspecs.id
    branch          = "main"
    build_source_type = "DEVOPS_CODE_REPOSITORY"
  }
}

# ─── Frontend Build Pipeline ──────────────────────────────────────────────────

resource "oci_devops_build_pipeline" "frontend" {
  project_id    = oci_devops_project.main.id
  display_name  = "${local.prefix}-build-frontend"
  description   = "Builds Angular frontend and uploads to OCI Object Storage"
  freeform_tags = local.common_tags

  build_pipeline_parameters {
    items {
      name          = "REGION"
      default_value = var.region
      description   = "OCI region"
    }
    items {
      name          = "TENANCY_NAMESPACE"
      default_value = local.tenancy_namespace
      description   = "OCI tenancy namespace"
    }
    items {
      name          = "FRONTEND_IMAGE_REPO"
      default_value = local.frontend_image_repo
      description   = "OCIR repository path for frontend image"
    }
    items {
      name          = "IMAGE_TAG"
      default_value = var.image_tag
      description   = "Docker image tag"
    }
    items {
      name          = "SOURCE_BUCKET"
      default_value = local.source_bucket_name
      description   = "Object Storage bucket holding app_source.zip"
    }
    items {
      name          = "FRONTEND_BUCKET"
      default_value = local.frontend_bucket_name
      description   = "Object Storage bucket for Angular static files"
    }
    items {
      name          = "API_GATEWAY_URL"
      default_value = "REPLACE_AT_RUNTIME"
      description   = "OCI API Gateway base URL injected into Angular environment"
    }
    items {
      name          = "DEVOPS_GIT_USERNAME"
      default_value = var.devops_git_username
      description   = "OCIR docker login username"
    }
    items {
      name          = "AUTH_TOKEN"
      default_value = "REPLACE_AT_RUNTIME"
      description   = "OCI Auth Token (overridden at trigger time)"
    }
  }
}

resource "oci_devops_build_pipeline_stage" "frontend_build" {
  build_pipeline_id = oci_devops_build_pipeline.frontend.id
  display_name      = "build-and-upload-frontend"
  stage_type        = "BUILD"
  description       = "Build Angular app and upload static files to Object Storage"
  freeform_tags     = local.common_tags

  build_spec_file   = "build_specs/frontend_build_spec.yaml"
  image             = "OL7_X86_64"

  build_pipeline_stage_predecessor_collection {
    items {
      id = oci_devops_build_pipeline.frontend.id
    }
  }

  primary_build_source {
    connection_type   = "DEVOPS_CODE_REPOSITORY"
    name              = "buildspecs-repo"
    repository_id     = oci_devops_repository.buildspecs.id
    branch            = "main"
    build_source_type = "DEVOPS_CODE_REPOSITORY"
  }
}
