# Machine secrets for the Talos cluster
resource "talos_machine_secrets" "main" {}

data "talos_client_configuration" "main" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.main.client_configuration

  # Aggregate all nodes (all classes)
  nodes = [for node in local.nodes : node.ipv4.vm_ip]

  # Only aggregate apiserver nodes for the endpoints
  endpoints = [for node in local.nodes : node.ipv4.vm_ip if node.node_class == "apiserver"]
}

# Talos Machine Configurations
data "talos_machine_configuration" "main" {
  for_each = {
    for node in local.nodes : "${node.cluster_name}-${node.node_class}-${node.index}" => node
    if node.node_class != "etcd" # Handle both control plane and worker nodes, excluding etcd
  }

  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${local.cluster_config.networking.vip.ip}:6443"
  machine_type     = each.value.node_class == "apiserver" ? "controlplane" : "worker"
  machine_secrets  = talos_machine_secrets.main.machine_secrets
  talos_version    = local.cluster_config.talos.talos_version
  kubernetes_version = local.cluster_config.talos.k8s_version
  docs = false
  examples = false
  config_patches = [
    templatefile("${path.module}/talosconfig.yaml.tpl", {
      is_control_plane  = each.value.node_class == "apiserver" # Conditionally set for control plane
      hostname          = each.key
      ipv4_local        = each.value.ipv4.vm_ip
      ipv6_local        = each.value.ipv6.vm_ip
      tailscale_authkey = var.tailscale_authkey
      cluster_config    = local.cluster_config
    })
  ]
}

# Apply Configuration to all nodes
resource "talos_machine_configuration_apply" "main" {
  for_each = {
    for node in local.nodes : "${node.cluster_name}-${node.node_class}-${node.index}" => node
    if node.node_class != "etcd" # Apply to both control plane and worker nodes
  }

  depends_on = [ proxmox_virtual_environment_vm.node ]

  client_configuration = talos_machine_secrets.main.client_configuration
  machine_configuration_input = data.talos_machine_configuration.main[each.key].machine_configuration
  node = each.value.ipv4.vm_ip
}

# Bootstrap the control plane using the first control plane node
resource "talos_machine_bootstrap" "main" {
  for_each = {
    for node in local.nodes : "${node.cluster_name}-${node.node_class}-${node.index}" => node
    if node.node_class == "apiserver" && node.index == 0
  }
  depends_on           = [ talos_machine_configuration_apply.main ]

  client_configuration = talos_machine_secrets.main.client_configuration
  node                 = each.value.ipv4.vm_ip
}

# Retrieve the Kubeconfig for the Talos cluster
resource "talos_cluster_kubeconfig" "main" {
  depends_on           = [ talos_machine_bootstrap.main ]

  client_configuration = talos_machine_secrets.main.client_configuration
  node                 = local.cluster_config.networking.vip.ip
}

# # Check Talos cluster health after the configurations are applied
# data "talos_cluster_health" "main" {
#   depends_on           = [
#     null_resource.install_cilium
#   ]
#
#   client_configuration = data.talos_client_configuration.main.client_configuration
#   control_plane_nodes = [for node in local.nodes : node.ipv4.vm_ip if node.node_class == "apiserver"]
#   worker_nodes = [for node in local.nodes : node.ipv4.vm_ip if node.node_class != "apiserver" && node.node_class != "etcd"]
#   endpoints            = data.talos_client_configuration.main.endpoints
#   timeouts = {
#     read = "5m"
#   }
# }

output "talosconfig" {
  value = data.talos_client_configuration.main.talos_config
  sensitive = true
}

output "kubeconfig" {
  value = talos_cluster_kubeconfig.main.kubeconfig_raw
  sensitive = true
}
