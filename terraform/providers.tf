terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.64.0"
    }
    unifi = {
      source = "paultyng/unifi"
      version = "0.41.0"
    }
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
    username = var.proxmox_username
    agent = true
  }
  insecure = true
}