# Dynamic creation of control plane (cp) nodes based on the selected cluster configuration
# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm
resource "proxmox_virtual_environment_vm" "node" {
  depends_on = [proxmox_virtual_environment_pool.operations_pool]
  for_each = { for node in local.nodes : "${node.cluster_name}-${node.node_class}-${node.index}" => node }

  description  = "Managed by Terraform"
  vm_id = each.value.vm_id
  name = "${each.value.cluster_name}-${each.value.node_class}-${each.value.index}"
  tags = [
    "k8s",
    each.value.cluster_name,
    each.value.node_class,
  ]
  node_name = var.proxmox_node
  clone {
    vm_id = var.template_vm_id
    full = true
    retries = 25 # Proxmox errors with timeout when creating multiple clones at once
  }
  cpu {
    cores    = each.value.cores
    sockets  = each.value.sockets
    numa = true
    type = "x86-64-v2-AES"
    flags = []
  }
  memory {
    dedicated = each.value.memory
  }
  dynamic "disk" {
    for_each = each.value.disks
    content {
      interface     = "virtio${disk.value.index}"
      size          = disk.value.size
      datastore_id  = disk.value.datastore
      file_format   = "raw"
      backup        = disk.value.backup # backup the disks during vm backup
      # https://pve.proxmox.com/wiki/Performance_Tweaks
      iothread      = true
      cache         = "writeback" # none is proxmox default. Writeback provides a little extra speed with more risk during power failure.
      aio           = "native"    # io_uring is proxmox default. Native can only be used with raw block devices.
      discard       = "ignore"    # proxmox default
      ssd           = false       # not possible with virtio
    }
  }
  agent {
    enabled = true
    timeout = "15m"
    trim = true
    type = "virtio"
  }
  vga {
    memory = 16
    type = "std" #"serial0"
  }
  initialization {
    interface = "ide2"
    user_account {
      keys = [var.vm_ssh_key]
      password = var.vm_password
      username = var.vm_username
    }
    datastore_id = each.value.disks[0].datastore
    dynamic "ip_config" {
      for_each = [1]  # This ensures the block is always created
      content {
        dynamic "ipv4" {
          for_each = [1]  # This ensures the block is always created
          content {
            address = "${each.value.ipv4.vm_ip}/24"
            gateway = each.value.ipv4.gateway
          }
        }

        dynamic "ipv6" {
          for_each = each.value.ipv6.enabled ? [1] : []
          content {
            address = "${each.value.ipv6.vm_ip}/64"
            gateway = each.value.ipv6.gateway
          }
        }
      }
    }
    dns {
      domain = each.value.dns_search_domain
      servers = concat(
        [each.value.ipv4.dns1, each.value.ipv4.dns2, each.value.ipv4.gateway],
          each.value.ipv6.enabled ? [each.value.ipv6.dns1, each.value.ipv6.dns2] : []
      )
    }
  }
  network_device {
    vlan_id  = each.value.vlan_id
    bridge   = each.value.bridge
    firewall = true # we'll toggle the firewall at the node level so it can be toggled w/ terraform without restarting the node
  }
  reboot = false # reboot is performed during the ./install_k8s.sh script, but only when needed, and only on nodes not part of the cluster already.
  migrate = true
  on_boot = each.value.on_boot
  started = true
  pool_id = upper(each.value.cluster_name)
  lifecycle {
    ignore_changes = [
      tags,
      description,
      clone,
      operating_system,
      disk, # don't remake disks, could cause data loss! Can comment this out if no production data is present
    ]
  }
}