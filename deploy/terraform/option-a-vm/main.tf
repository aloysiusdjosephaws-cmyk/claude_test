terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
  }
}

provider "oci" {
  tenancy_ocid          = var.tenancy_ocid
  user_ocid             = var.user_ocid
  fingerprint           = var.fingerprint
  private_key_path      = var.private_key_path
  private_key_password  = var.private_key_password
  region                = var.region
}

# ─── Data sources ─────────────────────────────────────────────────────────────

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "ubuntu_x86" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = var.instance_shape
  state                    = "AVAILABLE"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# ─── Networking ───────────────────────────────────────────────────────────────

resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  cidr_block     = "10.0.0.0/16"
  display_name   = "app-manager-vcn"
  dns_label      = "appmanager"
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "app-manager-igw"
  enabled        = true
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "app-manager-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

resource "oci_core_security_list" "app" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "app-manager-sl"

  # Allow all outbound traffic
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # SSH
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }

  # Angular UI — only reachable from within the VCN (API Gateway uses private IP)
  ingress_security_rules {
    protocol = "6"
    source   = "10.0.0.0/16"
    tcp_options {
      min = 4200
      max = 4200
    }
  }

  # Backend API ports (optional — needed if calling APIs directly from outside)
  dynamic "ingress_security_rules" {
    for_each = var.open_api_ports ? [1] : []
    content {
      protocol = "6"
      source   = "0.0.0.0/0"
      tcp_options {
        min = 8081
        max = 8084
      }
    }
  }
}

resource "oci_core_subnet" "public" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.main.id
  cidr_block        = "10.0.1.0/24"
  display_name      = "app-manager-public-subnet"
  dns_label         = "public"
  route_table_id    = oci_core_route_table.public.id
  security_list_ids = [oci_core_security_list.app.id]
}

# ─── Compute instance ─────────────────────────────────────────────────────────

resource "oci_core_instance" "app_vm" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain_index].name
  display_name        = "app-manager-vm"
  shape               = var.instance_shape

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory_gb
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu_x86.images[0].id
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    display_name     = "app-manager-vnic"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(local.cloud_init)
  }
}

# ─── Cloud-init: install Docker on first boot ─────────────────────────────────

locals {
  cloud_init = <<-EOT
    #!/bin/bash
    apt-get update -y
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    usermod -aG docker ubuntu
    systemctl enable docker
    systemctl start docker
  EOT
}

# ─── OCI API Gateway ──────────────────────────────────────────────────────────

resource "oci_apigateway_gateway" "main" {
  compartment_id = var.compartment_ocid
  endpoint_type  = "PUBLIC"
  subnet_id      = oci_core_subnet.public.id
  display_name   = "app-manager-gateway"
}

resource "oci_apigateway_deployment" "main" {
  compartment_id = var.compartment_ocid
  gateway_id     = oci_apigateway_gateway.main.id
  display_name   = "app-manager-deployment"
  path_prefix    = "/"

  specification {
    routes {
      path    = "/{path*}"
      methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD", "PATCH"]
      backend {
        type = "HTTP_BACKEND"
        url  = "http://${oci_core_instance.app_vm.private_ip}:4200/{path}"
      }
    }
  }
}

# ─── Outputs ──────────────────────────────────────────────────────────────────

output "vm_public_ip" {
  value = oci_core_instance.app_vm.public_ip
}

output "api_gateway_url" {
  description = "Public HTTPS endpoint for the API Gateway"
  value       = "https://${oci_apigateway_gateway.main.hostname}"
}
