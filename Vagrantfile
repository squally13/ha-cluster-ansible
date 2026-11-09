# -*- mode: ruby -*-
# Środowisko labu ha-homelab — etap 1 (Fundament).
# Lista maszyn pochodzi WYŁĄCZNIE z inventories/lab/hosts.yml (R3, ADR 0009).
require "yaml"
require "fileutils"

ROOT        = File.dirname(File.expand_path(__FILE__))
INVENTORY   = File.join(ROOT, "inventories", "lab", "hosts.yml")
LAB_KEY     = File.join(ROOT, ".lab", "ssh", "id_ed25519")
BOX         = "bento/debian-13"
BOX_VERSION = "202510.26.0" # weryfikacja: docs/notes.md (T007), ADR 0001

# Para kluczy labu (R5, ADR 0005): generowana raz, przy pierwszym uruchomieniu Vagranta.
unless File.exist?(LAB_KEY)
  FileUtils.mkdir_p(File.dirname(LAB_KEY))
  ok = system("ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-C", "ha-homelab-lab", "-f", LAB_KEY)
  abort "Nie udało się wygenerować klucza labu (#{LAB_KEY}) — sprawdź, czy ssh-keygen jest w PATH." unless ok
end
LAB_PUBKEY = File.read("#{LAB_KEY}.pub").strip

# Węzły z inventory: { name:, ip:, memory:, group: }; ops tworzony na końcu (bootstrap ops
# instaluje Ansible, gdy pozostałe węzły już istnieją).
inventory = YAML.load_file(INVENTORY)
nodes = []
inventory.fetch("all").fetch("children").each do |group, data|
  (data["hosts"] || {}).each do |name, vars|
    nodes << { name: name, ip: vars.fetch("ansible_host"), memory: vars.fetch("vagrant_memory"), group: group }
  end
end
nodes.sort_by! { |n| n[:group] == "ops" ? 1 : 0 }

Vagrant.configure("2") do |config|
  config.vm.box = BOX
  config.vm.box_version = BOX_VERSION
  config.vm.box_check_update = false

  # Folder współdzielony tylko na ops (R6, ADR 0008) — tu domyślnie wyłączony.
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # Celowo BEZ config.vm.hostname (R4, ADR 0009): Vagrant dopisałby nazwę na 127.0.1.1,
  # a nazwę hosta i /etc/hosts ustawia rola common.

  nodes.each do |node|
    config.vm.define node[:name] do |machine|
      machine.vm.network "private_network", ip: node[:ip]

      machine.vm.provider "virtualbox" do |vb|
        vb.name = "ha-homelab-#{node[:name]}"
        vb.memory = node[:memory]
        vb.cpus = 1
        vb.linked_clone = true
      end

      machine.vm.provision "bootstrap-node", type: "shell",
                           path: "vagrant/bootstrap-node.sh", args: [LAB_PUBKEY]

      if node[:group] == "ops"
        machine.vm.synced_folder ".", "/vagrant", disabled: false,
                                 mount_options: ["dmode=755", "fmode=644"]
        machine.vm.provision "bootstrap-ops", type: "shell", path: "vagrant/bootstrap-ops.sh"
      end
    end
  end
end
