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

variable "private_key_password" {
  description = "Passphrase for the encrypted OCI API signing private key"
  type        = string
  sensitive   = true
  default     = ""
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
  description = "SSH public key to install on the VM (paste contents of ~/.ssh/id_rsa.pub)"
  type        = string
}

variable "instance_shape" {
  description = "Compute shape — VM.Standard.E4.Flex (AMD x86_64). A1.Flex is ARM and frequently unavailable due to capacity."
  type        = string
  default     = "VM.Standard.E4.Flex"
}

variable "instance_ocpus" {
  description = "Number of OCPUs for the instance (minimum 2 for 4 Spring Boot services)"
  type        = number
  default     = 2
}

variable "instance_memory_gb" {
  description = "Memory in GB for the instance (minimum 8 GB for 4 Spring Boot services)"
  type        = number
  default     = 8
}

variable "availability_domain_index" {
  description = "Index of the availability domain to use (0=AD-1, 1=AD-2, 2=AD-3)"
  type        = number
  default     = 0
}

variable "open_api_ports" {
  description = "Whether to open ports 8081-8084 (backend APIs) in addition to 4200. Set true if calling APIs directly from outside the VM."
  type        = bool
  default     = false
}
