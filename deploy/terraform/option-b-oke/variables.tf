variable "tenancy_ocid" {
  description = "OCID of your OCI tenancy"
  type        = string
}

variable "user_ocid" {
  description = "OCID of the OCI user running Terraform"
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint of the API signing key"
  type        = string
}

variable "private_key_path" {
  description = "Path to the OCI API signing private key (PEM file)"
  type        = string
}

variable "region" {
  description = "OCI region (e.g. us-phoenix-1, ap-sydney-1)"
  type        = string
}

variable "compartment_ocid" {
  description = "OCID of the compartment to deploy into"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for OKE worker nodes"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for OKE (check available versions in OCI Console)"
  type        = string
  default     = "v1.30.1"
}

variable "node_shape" {
  description = "Shape for OKE worker nodes"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "node_ocpus" {
  description = "OCPUs per worker node"
  type        = number
  default     = 1
}

variable "node_memory_gb" {
  description = "Memory in GB per worker node"
  type        = number
  default     = 6
}

variable "node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 1
}
