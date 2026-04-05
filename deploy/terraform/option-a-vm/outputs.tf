output "instance_public_ip" {
  description = "Public IP address of the VM"
  value       = oci_core_instance.app_vm.public_ip
}

output "ssh_command" {
  description = "SSH command to connect to the VM"
  value       = "ssh ubuntu@${oci_core_instance.app_vm.public_ip}"
}

output "app_url" {
  description = "URL to access the application once deployed"
  value       = "http://${oci_core_instance.app_vm.public_ip}:4200"
}
