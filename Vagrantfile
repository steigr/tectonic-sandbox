# -*- mode: ruby -*-

require "./provisioning/tool"

node_provider = :vmware_fusion
node_name     = "kubernetes.sandbox"
node_ip       = "172.17.4.101"
node_config   = "provisioning/node"
node_cpus     = 4
node_memory   = 4096

Vagrant.configure("2") do |config|

  ARGV[0] == 'destroy' && cleanup(config)
  
  ARGV[0] == 'up' && provision(config,node_config,node_provider)

  config.vm.box = "coreos-alpha"
  config.vm.box_url = "build/coreos-alpha.json"
  
  config.vm.define vm_name = node_name
  config.vm.hostname = node_name
  config.ssh.insert_key = false
  config.ignition.enabled = true
  config.ignition.path = node_config + ".ign"

  config.vm.network "private_network", ip: node_ip

  config.vm.provider node_provider do |vmx|
    vmx.whitelist_verified = :disable_warning
    vmx.gui = false
    vmx.memory = node_memory
    vmx.vmx.merge!({
      "ethernet0.virtualdev" => "vmxnet3",
      "ethernet1.virtualdev" => "vmxnet3",
      "guestos" => "other4xlinux-64",
      "scsi0.virtualdev" => "pvscsi",
      "virtualhw.version" => "14",
      "virtualHW.productCompatibility" => "hosted",
      "firmware" => "efi",
      "vcpu.hotadd" => "TRUE",
      "mem.hotadd" => "TRUE",
      "vhv.enable" => "TRUE",
      "vvtd.enable" => "TRUE",
      "numvcpus" => node_cpus.to_s,
      "cpuid.coresPerSocket" => node_cpus.to_s,
      "usb.present" => "FALSE",
      "tools.syncTime" => "FALSE",
    })
  end
end
