# ─── OKE Cluster ─────────────────────────────────────────────────────────────

resource "oci_containerengine_cluster" "main" {
  compartment_id     = var.compartment_ocid
  name               = "${local.prefix}-oke"
  kubernetes_version = var.kubernetes_version
  vcn_id             = oci_core_vcn.main.id
  freeform_tags      = local.common_tags

  # Kubernetes API server endpoint — public so ORM runner and local machines can reach it
  endpoint_config {
    subnet_id             = oci_core_subnet.public.id
    is_public_ip_enabled  = true
  }

  options {
    service_lb_subnet_ids = [oci_core_subnet.public.id]

    add_ons {
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }

    kubernetes_network_config {
      pods_cidr     = "10.244.0.0/16"
      services_cidr = "10.96.0.0/16"
    }
  }
}

# ─── Node Pool ────────────────────────────────────────────────────────────────

resource "oci_containerengine_node_pool" "main" {
  compartment_id     = var.compartment_ocid
  cluster_id         = oci_containerengine_cluster.main.id
  name               = "${local.prefix}-nodepool"
  kubernetes_version = var.kubernetes_version
  freeform_tags      = local.common_tags

  node_shape = var.node_shape

  node_shape_config {
    ocpus         = var.node_ocpus
    memory_in_gbs = var.node_memory_gb
  }

  node_source_details {
    source_type             = "IMAGE"
    image_id                = data.oci_containerengine_node_pool_option.main.sources[0].image_id
    boot_volume_size_in_gbs = 50
  }

  ssh_public_key = var.ssh_public_key

  node_config_details {
    size = var.node_count

    placement_configs {
      availability_domain = local.ad1_name
      subnet_id           = oci_core_subnet.private.id
    }

    dynamic "placement_configs" {
      for_each = length(data.oci_identity_availability_domains.ads.availability_domains) > 1 ? [1] : []
      content {
        availability_domain = local.ad2_name
        subnet_id           = oci_core_subnet.private.id
      }
    }

    node_pool_pod_network_option_details {
      cni_type          = "FLANNEL_OVERLAY"
      pod_subnet_ids    = [oci_core_subnet.private.id]
    }
  }

  initial_node_labels {
    key   = "app"
    value = local.app
  }
}

# Node pool image source — Oracle Linux 8 for the selected node shape
data "oci_containerengine_node_pool_option" "main" {
  node_pool_option_id = oci_containerengine_cluster.main.id
  compartment_id      = var.compartment_ocid
}
