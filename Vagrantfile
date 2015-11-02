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

sudo route add default gw 172.10.10.22

sudo ifconfig eth1 inet6 add 2a00:1010:11::1/64
sudo echo -e "auto eth1\niface eth1 inet6 static\naddress 2a01:1010:11::1/64" >> /etc/network/interfaces

sudo ifconfig eth2 inet6 add 2a01:1010:20::21/64
sudo echo -e "auto eth2\niface eth2 inet6 static\naddress 2a01:1010:20::21/64" >> /etc/network/interfaces

SCRIPT

$router2 = <<SCRIPT

sudo ifconfig eth1 inet6 add 2a00:1010:12::1/64
sudo echo -e "auto eth1\niface eth1 inet6 static\naddress 2a01:1010:12::1/64" >> /etc/network/interfaces

sudo ifconfig eth2 inet6 add 2a01:1010:20::22/64
sudo echo -e "auto eth2\niface eth2 inet6 static\naddress 2a01:1010:20::22/64" >> /etc/network/interfaces

SCRIPT

$bind = <<SCRIPT

sudo apt-get update
sudo apt-get -y install bind9
sudo cp /vagrant/bind/named* /etc/bind/
sudo cp /vagrant/bind/exfil.zone /var/cache/bind
sudo service bind9 restart

SCRIPT

Vagrant.configure(2) do |config|
    
    config.vm.provider :virtualbox do |vb|
        vb.customize ["modifyvm", :id, "--memory", "1024"]
        vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
        vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
    end
    config.vm.define "router1" do |router1|
        router1.vm.box = "debian/jessie64"
        router1.vm.hostname = "router1"
        router1.vm.network "private_network", ip: "192.168.11.1", virtualbox__intnet: "victim_LAN", :bridge => "eth1"
        router1.vm.network "private_network", ip: "172.10.10.21", virtualbox__intnet: "pub_SINET", :bridge => "eth2"
        router1.vm.provision "shell", inline: $router1
        router1.vm.provision "shell", inline: $routing
        router1.vm.provision "shell", inline: $bind
    end
    config.vm.define "router2" do |router2|
        router2.vm.box = "debian/jessie64"
        router2.vm.hostname = "router2"
        router2.vm.network "private_network", ip: "192.168.12.1", virtualbox__intnet: "cnc_SINET", :bridge => "eth1"
        router2.vm.network "private_network", ip: "172.10.10.22", virtualbox__intnet: "pub_SINET", :bridge => "eth2"
        router2.vm.provision "shell", inline: $router2
        router2.vm.provision "shell", inline: $isp
        router2.vm.provision "shell", inline: $routing
        router2.vm.provision "shell", inline: $bind
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
    end
end