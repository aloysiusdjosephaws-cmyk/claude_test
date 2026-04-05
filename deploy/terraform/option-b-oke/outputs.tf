output "cluster_id" {
  description = "OCID of the OKE cluster"
  value       = oci_containerengine_cluster.oke.id
}

output "kubeconfig_command" {
  description = "Run this command to configure kubectl to connect to your OKE cluster"
  value       = "oci ce cluster create-kubeconfig --cluster-id ${oci_containerengine_cluster.oke.id} --file $HOME/.kube/config --region ${var.region} --token-version 2.0.0 --kube-endpoint PUBLIC_ENDPOINT"
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = oci_containerengine_cluster.oke.endpoints[0].public_endpoint
}
