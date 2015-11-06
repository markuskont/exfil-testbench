$isp = <<SCRIPT

sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -i eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -o eth0 -j ACCEPT

SCRIPT

$router1_persist = <<SCRIPT

sudo route del default

sudo cat <<IP4 >> /etc/network/interfaces

auto eth1
iface eth1 inet static
address 192.168.11.1
netmask 255.255.255.0
IP4

sudo cat <<IP6 >> /etc/network/interfaces

iface eth1 inet6 static
address 2a00:1010:11::1/64
IP6

sudo ifup eth1

sudo cat <<IP4 >> /etc/network/interfaces

auto eth2
iface eth2 inet static
address 172.10.10.21
netmask 255.255.255.0
gateway 172.10.10.22
IP4

sudo cat <<IP6 >> /etc/network/interfaces

iface eth2 inet6 static
address 2a01:1010:20::21/64
gateway 2a01:1010:20::22
IP6

sudo ifup eth2

SCRIPT

$router2_persist = <<SCRIPT

sudo cat <<IP4 >> /etc/network/interfaces

auto eth1
iface eth1 inet static
address 192.168.12.1
netmask 255.255.255.0
IP4

sudo cat <<IP6 >> /etc/network/interfaces

iface eth1 inet6 static
address 2a02:1010:12::1/64
IP6

sudo ifup eth1

sudo cat <<IP4 >> /etc/network/interfaces

auto eth2
iface eth2 inet static
address 172.10.10.22
netmask 255.255.255.0
up route add -net 192.168.11.0 netmask 255.255.255.0 gw 172.10.10.21
IP4

sudo cat <<IP6 >> /etc/network/interfaces

iface eth2 inet6 static
address 2a01:1010:20::22/64
up route -A inet6 add 2a00:1010:11::/64 gw 2a01:1010:20::21
IP6

sudo ifup eth2

SCRIPT

$host_persist = <<SCRIPT

sudo echo "host" > /etc/hostname
sudo service hostname.sh

sudo service network-manager stop
sudo update-rc.d -f network-manager remove
sudo route del default

sudo cat <<IP4 >> /etc/network/interfaces
auto eth1
iface eth1 inet static
address 192.168.11.11
netmask 255.255.255.0
gateway 192.168.11.1

IP4

sudo cat <<IP6 >> /etc/network/interfaces
iface eth1 inet6 static
address 2a00:1010:11::11/64
gateway 2a00:1010:11::1

IP6

sudo ifup eth1

SCRIPT

$cnc_persist = <<SCRIPT

sudo echo "cnc" > /etc/hostname
sudo service hostname.sh

sudo service network-manager stop
sudo update-rc.d -f network-manager remove
sudo route del default

sudo cat <<IP4 >> /etc/network/interfaces
auto eth1
iface eth1 inet static
address 192.168.12.12
netmask 255.255.255.0
gateway 192.168.12.1

IP4

sudo cat <<IP6 >> /etc/network/interfaces
iface eth1 inet6 static
address 2a02:1010:12::12/64
gateway 2a02:1010:12::1

IP6

sudo ifup eth1

SCRIPT

$monitoring = <<SCRIPT

apt-get update
apt-get install -y vim htop tmux build-essential tcpdump

SCRIPT

Vagrant.configure(2) do |config|
    
    config.vm.provider :virtualbox do |vb|
        vb.customize ["modifyvm", :id, "--memory", "1024"]
        vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
        vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
    end
    config.vm.define "router1" do |router1|
        router1.vm.network :forwarded_port, guest: 2022, host: 2021, id: 'ssh'
        router1.ssh.port = "2021"
        router1.ssh.guest_port = "2022"
        router1.vm.box = "exfil_router"
        router1.vm.hostname = "router1"
        # eth1
        router1.vm.network "private_network", ip: "192.168.11.1", virtualbox__intnet: "victim_LAN", auto_config: false
        # eth2
        router1.vm.network "private_network", ip: "172.10.10.21", virtualbox__intnet: "pub_SINET", auto_config: false
        router1.vm.provision "shell", inline: $router1_persist
    end
    config.vm.define "router2" do |router2|
        router2.vm.network :forwarded_port, guest: 2022, host: 2022, id: 'ssh'
        router2.ssh.port = "2022"
        router2.ssh.guest_port = "2022"
        router2.vm.box = "exfil_router"
        router2.vm.hostname = "router2"
        # eth1
        router2.vm.network "private_network", ip: "192.168.12.1", virtualbox__intnet: "cnc_SINET", auto_config: false
        # eth2
        router2.vm.network "private_network", ip: "172.10.10.22", virtualbox__intnet: "pub_SINET", auto_config: false
        router2.vm.provision "shell", inline: $router2_persist
        router2.vm.provision "shell", inline: $isp
        #router2.vm.network "public_network"
    end
    config.vm.define "host" do |host|
        host.vm.network :forwarded_port, guest: 2022, host: 2023, id: 'ssh'
        host.ssh.port = "2023"
        host.ssh.guest_port = "2022"
        host.vm.box = "exfil_kali"
        # eth1, ip4 is not configured by vagrant (see inline)
        host.vm.network "private_network", ip: "192.168.11.11", virtualbox__intnet: "victim_LAN", auto_config: false
        host.vm.provision "shell", inline: $host_persist
    end
    config.vm.define "cnc" do |cnc|
        cnc.vm.network :forwarded_port, guest: 2022, host: 2024, id: 'ssh'
        cnc.ssh.port = "2024"
        cnc.ssh.guest_port = "2022"
        cnc.vm.box = "exfil_kali"
        # eth1, ip4 is not configured by vagrant (see inline)
        cnc.vm.network "private_network", ip: "192.168.12.12", virtualbox__intnet: "cnc_SINET", auto_config: false
        cnc.vm.provision "shell", inline: $cnc_persist
    end
    config.vm.define "tap" do |tap|
        tap.vm.box = "ubuntu/trusty64"
        tap.vm.hostname = "tap"
        # eth1, no address assigned for packet capture
        tap.vm.network "private_network", ip: "0.0.0.0", virtualbox__intnet: "pub_SINET"
        config.vm.provider :virtualbox do |box|
            # nicpromisc2 = promisc on eth1
            box.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
            box.customize ["modifyvm", :id, "--memory", "4096"]
            box.customize ["modifyvm", :id, "--cpus", "2"]
        end
        tap.vm.provision "shell", inline: $monitoring
    end
end