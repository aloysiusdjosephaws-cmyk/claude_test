terraform {
  required_version = ">= 1.3"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

# When running in OCI Resource Manager the auth is automatically provided
# via resource-principal; no explicit credentials needed here.
provider "oci" {
  tenancy_ocid = var.tenancy_ocid
  region       = var.region
}
