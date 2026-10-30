Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"
  config.vm.hostname = "bookshop"
  config.vm.synced_folder ".", "/practice"
  config.vm.synced_folder ".", "/vagrant", disabled: true

  config.vm.provider "vmware_desktop" do |v|
    v.memory = 2048
    v.cpus = 2
    v.vmx["ethernet0.pcislotnumber"] = "160"
  end

  config.vm.provider "virtualbox" do |v|
    v.memory = 2048
    v.cpus = 2
  end
end
