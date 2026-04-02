output "frontend_url" {
  description = "Public URL of the Angular frontend (OCI Object Storage static hosting)."
  value       = "https://objectstorage.${var.region}.oraclecloud.com/n/${local.tenancy_namespace}/b/${oci_objectstorage_bucket.frontend.name}/o/index.html"
}

output "api_gateway_url" {
  description = "Base URL of the OCI API Gateway (routes to Spring Boot backend)."
  value       = local.api_gateway_base_url
}

output "backend_health_url" {
  description = "Backend health check URL (verify deployment)."
  value       = "${local.api_gateway_base_url}/actuator/health"
}

output "oke_cluster_id" {
  description = "OCID of the OKE Kubernetes cluster."
  value       = oci_containerengine_cluster.main.id
}

output "kubeconfig_command" {
  description = "Run this command to configure kubectl on your local machine."
  value       = "oci ce cluster create-kubeconfig --cluster-id ${oci_containerengine_cluster.main.id} --region ${var.region} --token-version 2.0.0 --kube-endpoint PUBLIC_ENDPOINT"
}

output "backend_ocir_image" {
  description = "OCIR path of the built backend image."
  value       = "${local.backend_image_repo}:${var.image_tag}"
}

output "devops_project_name" {
  description = "OCI DevOps project name."
  value       = oci_devops_project.main.name
}

output "frontend_bucket" {
  description = "Object Storage bucket name holding Angular static files."
  value       = oci_objectstorage_bucket.frontend.name
}
