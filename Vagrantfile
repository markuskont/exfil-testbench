$routing = <<SCRIPT
sudo echo 1 > /proc/sys/net/ipv4/ip_forward
sudo echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf

sudo echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
sudo echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.conf
SCRIPT

$isp = <<SCRIPT

sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -i eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -o eth0 -j ACCEPT

SCRIPT

$router1 = <<SCRIPT

sudo route del default
sudo route add default gw 172.10.10.22

sudo ifconfig eth1 inet6 add 2a00:1010:11::1/64
sudo ifconfig eth2 inet6 add 2a01:1010:20::21/64

sudo ip -6 route add default via 2a01:1010:20::22

SCRIPT

$router1_persist = <<SCRIPT

sudo echo -e "iface eth1 inet6 static\naddress 2a01:1010:11::1/64" >> /etc/network/interfaces
sudo echo -e "iface eth2 inet6 static\naddress 2a01:1010:20::21/64\ngateway 2a01:1010:20::22" >> /etc/network/interfaces

SCRIPT

$router2 = <<SCRIPT

sudo ifconfig eth1 inet6 add 2a00:1010:12::1/64
sudo ifconfig eth2 inet6 add 2a01:1010:20::22/64

sudo route add -net 192.168.11.0 netmask 255.255.255.0 gw 172.10.10.21
sudo route -A inet6 add 2a00:1010:11::/64 gw 2a01:1010:20::21

SCRIPT

$router2_persist = <<SCRIPT

sudo echo -e "iface eth1 inet6 static\naddress 2a01:1010:12::1/64\nup route add -net 192.168.11.0 netmask 255.255.255.0 gw 172.10.10.21\nup route -A inet6 add 2a00:1010:11::/64 gw 2a01:1010:20::21" >> /etc/network/interfaces
sudo echo -e "iface eth2 inet6 static\naddress 2a01:1010:20::22/64" >> /etc/network/interfaces

SCRIPT

$cnc = <<SCRIPT

sudo ifconfig eth1 inet6 add 2a02:1010:12::12/64
sudo echo -e "iface eth0 inet6 static\naddress 2a02:1010:12::12/64\ngateway 2a02:1010:12::1

sudo ip -6 route add default via 2a02:1010:12::1

SCRIPT

$bind = <<SCRIPT

sudo apt-get update
sudo apt-get -y install bind9
sudo cp /vagrant/bind/named* /etc/bind/
sudo cp /vagrant/bind/exfil.zone /var/cache/bind
sudo service bind9 restart

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
    config.vm.define "router2" do |router2|
        router2.vm.box = "debian/jessie64"
        router2.vm.hostname = "router2"
        router2.vm.network "private_network", ip: "192.168.12.1", virtualbox__intnet: "cnc_SINET"
        router2.vm.network "private_network", ip: "172.10.10.22", virtualbox__intnet: "pub_SINET"
        router2.vm.provision "shell", inline: $router2
        router2.vm.provision "shell", inline: $isp
        router2.vm.provision "shell", inline: $routing
        router2.vm.provision "shell", inline: $bind
        #router2.vm.network "public_network"
    end
    config.vm.define "router1" do |router1|
        router1.vm.box = "debian/jessie64"
        router1.vm.hostname = "router1"
        router1.vm.network "private_network", ip: "192.168.11.1", virtualbox__intnet: "victim_LAN"
        router1.vm.network "private_network", ip: "172.10.10.21", virtualbox__intnet: "pub_SINET"
        router1.vm.provision "shell", inline: $router1
        router1.vm.provision "shell", inline: $routing
        router1.vm.provision "shell", inline: $bind
    end
    config.vm.define "host" do |host|
        host.vm.box = "blackfin/kali"
        host.vm.hostname = "host"
        host.vm.network "private_network", ip: "192.168.11.11", virtualbox__intnet: "victim_LAN"
        #host.vm.provision "shell", inline: $router1
    end
    config.vm.define "cnc" do |cnc|
        cnc.vm.box = "blackfin/kali"
        cnc.vm.hostname = "cnc"
        cnc.vm.network "private_network", ip: "192.168.12.12", virtualbox__intnet: "cnc_SINET"
        #cnc.vm.provision "shell", inline: $router1
    end
    config.vm.define "tap" do |tap|
        tap.vm.box = "ubuntu/trusty64"
        tap.vm.hostname = "tap"
        tap.vm.network "private_network", ip: "0.0.0.0", virtualbox__intnet: "pub_SINET"
        config.vm.provider :virtualbox do |box|
            box.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
            box.customize ["modifyvm", :id, "--memory", "4096"]
            box.customize ["modifyvm", :id, "--cpus", "2"]
        end
        tap.vm.provision "shell", inline: $monitoring
    end
end