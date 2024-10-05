locals {
  ipv6 = local.cluster_config.networking.ipv6.enabled && local.cluster_config.networking.ipv6.dual_stack ? true : false
}

resource "null_resource" "install_cilium" {
  depends_on = [ talos_machine_bootstrap.main ]

  provisioner "local-exec" {
    command = <<EOT
      KUBECONFIG=~/.kube/${local.cluster_config.kubeconfig_file_name} \
      cilium install \
      --version v${local.cluster_config.networking.cilium.cilium_version} \
      --namespace kube-system \
      --set cluster.id=${local.cluster_config.cluster_id} \
      --set cluster.name=${local.cluster_config.cluster_name} \
      --set operator.replicas=2 \
      --set rolloutCiliumPods=true \
      --set operator.rollOutPods=true \
      --set ipv4.enabled=true \
      --set ipv6.enabled=${local.ipv6} \
      --set ipam.mode=kubernetes \
      --set externalIPs.enabled=true \
      --set nodePort.enabled=true \
      --set hostPort.enabled=true \
      --set bpf.masquerade=true \
      --set kubeProxyReplacement=true \
      --set securityContext.capabilities.ciliumAgent='{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}' \
      --set securityContext.capabilities.cleanCiliumState='{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}' \
      --set cgroup.autoMount.enabled=false \
      --set cgroup.hostRoot=/sys/fs/cgroup \
      --set k8sServiceHost=localhost \
      --set k8sServicePort=7445 \
      && \
      KUBECONFIG=~/.kube/${local.cluster_config.kubeconfig_file_name} \
      cilium status --wait
    EOT
  }
}
