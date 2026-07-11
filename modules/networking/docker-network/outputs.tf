output "id" {
  description = "The Docker-assigned ID of the network."
  value       = docker_network.this.id
}

output "name" {
  description = "The name of the network as declared."
  value       = docker_network.this.name
}

output "driver" {
  description = "The network driver in use."
  value       = docker_network.this.driver
}

output "subnet" {
  description = "The CIDR subnet assigned to the network (from ipam_config if provided, otherwise Docker-assigned)."
  # ipam_config is a set — use one() to safely extract the single element, or null if empty.
  value = length(docker_network.this.ipam_config) > 0 ? one(docker_network.this.ipam_config).subnet : null
}
