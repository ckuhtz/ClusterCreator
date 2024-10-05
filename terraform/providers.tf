terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = ">= 0.64.0"
    }
    unifi = {
      source = "paultyng/unifi"
      version = ">= 0.41.0"
    }
    talos = {
      source = "siderolabs/talos"
      version = ">= 0.6.0"
    }
  }

  backend "s3" {
    bucket = "terraform-state"
    key    = "clustercreator.tfstate"
    region = "default"

    use_path_style              = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
  }
}

provider "unifi" {
  username = var.unifi_username
  password = var.unifi_password
  api_url  = var.unifi_api_url
  allow_insecure = true
}

provider "proxmox" {
  endpoint = "https://${var.proxmox_host}:8006/api2/json"
  api_token = var.proxmox_api_token
  ssh {
    agent = true
    username = var.proxmox_username
    private_key = file(var.proxmox_ssh_key)
  }
  insecure = true
}
