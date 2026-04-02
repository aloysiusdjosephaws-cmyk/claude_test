# ─── VCN ─────────────────────────────────────────────────────────────────────

resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.prefix}-vcn"
  cidr_blocks    = ["10.0.0.0/16"]
  dns_label      = replace(local.app, "-", "")
  freeform_tags  = local.common_tags
}

# ─── Gateways ────────────────────────────────────────────────────────────────

resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.prefix}-igw"
  enabled        = true
  freeform_tags  = local.common_tags
}

resource "oci_core_nat_gateway" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.prefix}-natgw"
  freeform_tags  = local.common_tags
}

resource "oci_core_service_gateway" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.prefix}-svcgw"
  freeform_tags  = local.common_tags

  services {
    service_id = data.oci_core_services.all.services[0].id
  }
}

data "oci_core_services" "all" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

# ─── Route Tables ─────────────────────────────────────────────────────────────

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.prefix}-rt-public"
  freeform_tags  = local.common_tags

  route_rules {
    network_entity_id = oci_core_internet_gateway.main.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
}

resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.prefix}-rt-private"
  freeform_tags  = local.common_tags

  route_rules {
    network_entity_id = oci_core_nat_gateway.main.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }

  route_rules {
    network_entity_id = oci_core_service_gateway.main.id
    destination       = data.oci_core_services.all.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
  }
}

# ─── Security Lists ───────────────────────────────────────────────────────────

# Public subnet: Kubernetes API endpoint + OCI Load Balancers + API Gateway
resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.prefix}-sl-public"
  freeform_tags  = local.common_tags

  # Allow all egress
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    stateless   = false
  }

  # Kubernetes API server (for kubectl / helm from ORM runner and local machine)
  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "6" # TCP
    stateless = false
    tcp_options {
      min = 6443
      max = 6443
    }
  }

  # HTTP/HTTPS for Load Balancers and API Gateway
  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "6"
    stateless = false
    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "6"
    stateless = false
    tcp_options {
      min = 443
      max = 443
    }
  }

  # OKE control plane → nodes (health checks, webhooks)
  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "6"
    stateless = false
    tcp_options {
      min = 10256
      max = 10256
    }
  }

  # Allow all intra-VCN traffic
  ingress_security_rules {
    source    = "10.0.0.0/16"
    protocol  = "all"
    stateless = false
  }
}

# Private subnet: OKE worker nodes
resource "oci_core_security_list" "private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.prefix}-sl-private"
  freeform_tags  = local.common_tags

  # Allow all egress (NAT gateway handles internet access)
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    stateless   = false
  }

  egress_security_rules {
    destination      = data.oci_core_services.all.services[0].cidr_block
    destination_type = "SERVICE_CIDR_BLOCK"
    protocol         = "all"
    stateless        = false
  }

  # Allow all intra-VCN traffic (pod-to-pod, control plane, LB health checks)
  ingress_security_rules {
    source    = "10.0.0.0/16"
    protocol  = "all"
    stateless = false
  }

  # NodePort range from Load Balancer
  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "6"
    stateless = false
    tcp_options {
      min = 30000
      max = 32767
    }
  }
}

# ─── Subnets ──────────────────────────────────────────────────────────────────

resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  display_name               = "${local.prefix}-subnet-public"
  cidr_block                 = "10.0.0.0/24"
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.public.id]
  prohibit_public_ip_on_vnic = false
  dns_label                  = "public"
  freeform_tags              = local.common_tags
}

resource "oci_core_subnet" "private" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  display_name               = "${local.prefix}-subnet-private"
  cidr_block                 = "10.0.1.0/24"
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.private.id]
  prohibit_public_ip_on_vnic = true
  dns_label                  = "private"
  freeform_tags              = local.common_tags
}
