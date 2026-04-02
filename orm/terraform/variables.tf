# ─── OCI Identity ────────────────────────────────────────────────────────────

variable "tenancy_ocid" {
  description = "OCID of the OCI tenancy."
  type        = string
}

variable "compartment_ocid" {
  description = "OCID of the compartment to deploy all resources in."
  type        = string
}

variable "region" {
  description = "OCI region identifier (e.g. us-phoenix-1, ap-singapore-1)."
  type        = string
}

# ─── Authentication ──────────────────────────────────────────────────────────

variable "auth_token" {
  description = "OCI Auth Token for OCIR docker login and DevOps code repository git push."
  type        = string
  sensitive   = true
}

variable "devops_git_username" {
  description = "Full git username for OCI DevOps Code Repository HTTPS auth. Example: mynamespace/oracleidentitycloudservice/user@company.com"
  type        = string
}

# ─── OKE ─────────────────────────────────────────────────────────────────────

variable "ssh_public_key" {
  description = "SSH public key for OKE worker nodes."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the OKE cluster."
  type        = string
  default     = "v1.29.1"
}

variable "node_shape" {
  description = "Compute shape for OKE worker nodes."
  type        = string
  default     = "VM.Standard.E4.Flex"
}

variable "node_ocpus" {
  description = "OCPUs per worker node (Flex shapes only)."
  type        = number
  default     = 2
}

variable "node_memory_gb" {
  description = "Memory in GB per worker node (Flex shapes only)."
  type        = number
  default     = 16
}

variable "node_count" {
  description = "Number of OKE worker nodes."
  type        = number
  default     = 2
}

# ─── Application ─────────────────────────────────────────────────────────────

variable "app_name" {
  description = "Short name used as prefix for all resource names (lowercase, no spaces)."
  type        = string
  default     = "fileservice"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.app_name))
    error_message = "app_name must start with a lowercase letter and contain only lowercase letters, digits, and hyphens."
  }
}

variable "image_tag" {
  description = "Docker image tag for built container images."
  type        = string
  default     = "latest"
}
