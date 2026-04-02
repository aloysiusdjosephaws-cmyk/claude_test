# Object Storage namespace (same as tenancy namespace)
data "oci_objectstorage_namespace" "tenancy" {
  compartment_id = var.tenancy_ocid
}

# Availability domains in the target region
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# First availability domain (used for node pool placement)
locals {
  ad1_name = data.oci_identity_availability_domains.ads.availability_domains[0].name
  ad2_name = length(data.oci_identity_availability_domains.ads.availability_domains) > 1 ? data.oci_identity_availability_domains.ads.availability_domains[1].name : local.ad1_name
}
