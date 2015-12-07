$isp = <<SCRIPT

sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -i eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -o eth0 -j ACCEPT

SCRIPT

$router1_persist = <<SCRIPT

#sudo route del default

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
pre-up route del default
IP4

sudo cat <<IP6 >> /etc/network/interfaces

iface eth2 inet6 static
address 2a01:1010:20::21/64
gateway 2a01:1010:20::22
IP6

sudo ifup eth2

sudo cat <<IP4 >> /etc/network/interfaces

auto eth3
iface eth3 inet static
address 192.168.56.191
netmask 255.255.255.0
IP4

sudo ifup eth3

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

sudo cat <<IP4 >> /etc/network/interfaces

auto eth3
iface eth3 inet static
address 192.168.56.192
netmask 255.255.255.0
IP4

sudo ifup eth3

SCRIPT

$host_persist = <<SCRIPT

sudo echo "host" > /etc/hostname
sudo service hostname.sh

sudo service network-manager stop
sudo update-rc.d -f network-manager remove
#sudo route del default

sudo cat <<IP4 >> /etc/network/interfaces
auto eth1
iface eth1 inet static
address 192.168.11.11
netmask 255.255.255.0
gateway 192.168.11.1
pre-up route del default

IP4

sudo cat <<IP6 >> /etc/network/interfaces
iface eth1 inet6 static
address 2a00:1010:11::11/64
gateway 2a00:1010:11::1

IP6

sudo ifup eth1

sudo cat <<IP4 >> /etc/network/interfaces

auto eth2
iface eth2 inet static
address 192.168.56.193
netmask 255.255.255.0
IP4

sudo ifup eth2

SCRIPT

$cnc_persist = <<SCRIPT

sudo echo "cnc" > /etc/hostname
sudo service hostname.sh

sudo service network-manager stop
sudo update-rc.d -f network-manager remove
#sudo route del default

sudo cat <<IP4 >> /etc/network/interfaces
auto eth1
iface eth1 inet static
address 192.168.12.12
netmask 255.255.255.0
gateway 192.168.12.1
pre-up route del default

IP4

sudo cat <<IP6 >> /etc/network/interfaces
iface eth1 inet6 static
address 2a02:1010:12::12/64
gateway 2a02:1010:12::1

IP6

sudo ifup eth1

sudo cat <<IP4 >> /etc/network/interfaces

auto eth2
iface eth2 inet static
address 192.168.56.194
netmask 255.255.255.0
IP4

sudo ifup eth2

SCRIPT

$monitoring = <<SCRIPT

apt-get update
apt-get install -y vim htop tmux build-essential tcpdump

sudo cat <<IP4 >> /etc/network/interfaces

auto eth2
iface eth2 inet static
address 192.168.56.195
netmask 255.255.255.0
IP4

sudo ifup eth2

SCRIPT

$bro = <<SCRIPT
wget -q http://download.opensuse.org/repositories/network:bro/xUbuntu_14.04/Release.key
sleep 1
sudo apt-key add - < Release.key
sleep 1
sudo sh -c "echo 'deb http://download.opensuse.org/repositories/network:/bro/xUbuntu_14.04/ /' >> /etc/apt/sources.list.d/bro.list"
sudo apt-get update
sudo apt-get -y --force-yes install bro

sudo cat <<EOF > /opt/bro/etc/networks.cfg
192.168.11.0/24     Private IP space
2a00:1010:11::/64   Private IP space
EOF

sed -i 's/^interface=.*/interface=eth1/g' /opt/bro/etc/node.cfg

sudo echo '@load tuning/json-logs' >> /opt/bro/share/bro/site/local.bro
sudo /opt/bro/bin/broctl install

sudo mkdir /opt/bro/share/bro/custom/
sudo cp /opt/bro/spool/installed-scripts-do-not-touch/auto/local-networks.bro /opt/bro/share/bro/custom/
sudo echo '@load custom/local-networks.bro' >> /opt/bro/share/bro/site/local.bro

sudo /opt/bro/bin/broctl install
sudo /opt/bro/bin/broctl check

SCRIPT

$suricata = <<SCRIPT
sudo add-apt-repository -y ppa:oisf/suricata-beta
sudo apt-get update
sudo apt-get -y install suricata-dbg
sudo service suricata status
sudo service suricata stop
sudo update-rc.d -f suricata remove

sudo sed -i -r "/unix-command:/I{n; s/enabled: no/enabled: yes/}" /etc/suricata/suricata.yaml
sudo sed -i 's/#- newflow/- netflow/g' /etc/suricata/suricata.yaml

sudo apt-get install -y oinkmaster
sudo cat << EOF >> /etc/oinkmaster.conf
url = http://rules.emergingthreats.net/open/suricata/emerging.rules.tar.gz
EOF

sudo oinkmaster -C /etc/oinkmaster.conf -o /etc/suricata/rules

sudo sed -i 's/\# - emerging-icmp\\.rules/ - emerging-icmp.rules/g' /etc/suricata/suricata.yaml
sudo sed -i 's/classification-file.*/classification-file: \\/etc\\/suricata\\/rules\\/classification.config/g' /etc/suricata/suricata.yaml
sudo sed -i 's/reference-config-file.*/reference-config-file: \\/etc\\/suricata\\/rules\\/reference.config/g' /etc/suricata/suricata.yaml
sudo sed -i  's/HOME_NET:.*/HOME_NET: "[192.168.11.0\\/24,2a00:1010:11::\\/64]"/g' /etc/suricata/suricata.yaml
sudo sed -i 's/linux: \\[10.0.0.0.*/linux: [0.0.0.0\\/0,"2a00:1010:11::\\/64","2a02:1010:12::\\/64","2a01:1010:20::\\/64"]/g' /etc/suricata/suricata.yaml
sudo sed -i 's/LISTENMODE=af-packet/LISTENMODE=pcap/g' /etc/default/suricata
sudo sed -i 's/IFACE=eth0/IFACE=eth1/g' /etc/default/suricata

SCRIPT

$snort = <<SCRIPT
#echo snort snort/address_range string 192.168.11.0/24 | debconf-set-selections
#sudo apt-get -y install snort

sudo service snort stop
sudo update-rc.d -f snort remove

sudo wget https://www.snort.org/downloads/snort/daq-2.0.6.tar.gz
sudo wget https://www.snort.org/downloads/snort/snort-2.9.8.0.tar.gz

sudo apt-get -y install flex libbison-dev libpcap-dev libpcre3-dev libdnet-dev libdumbnet-dev libghc-zlib-dev

tar xvfz daq-2.0.6.tar.gz
cd daq-2.0.6
./configure
sudo make
sudo make install
sudo ldconfig
cd ..

tar xvfz snort-2.9.8.0.tar.gz
cd snort-2.9.8.0
sudo ./configure --enable-sourcefire --with-daq-includes=/opt/daq/lib/ --with-daq-libraries=/opt/daq/include/ 
sudo make 
sudo make install
cd ..

#sudo wget -O rules.tgz https://www.snort.org/rules/snortrules-snapshot-2976.tar.gz?oinkcode=<CODE>
#mkdir -p /vagrant/snort/sourcefire
#rm -r /vagrant/snort/sourcefire/*
#tar -xzf rules.tgz -C /vagrant/snort/sourcefire
#cp /vagrant/snort/snort-sourcefire.conf /vagrant/snort/sourcefire/snort.conf

SCRIPT

$elk = <<SCRIPT

sudo apt-get install openjdk-7-jre-headless -y

sudo wget -O - http://packages.elasticsearch.org/GPG-KEY-elasticsearch | apt-key add -
sudo echo 'deb http://packages.elasticsearch.org/elasticsearch/1.7/debian stable main' | tee /etc/apt/sources.list.d/elasticsearch.list
sudo echo 'deb http://packages.elasticsearch.org/logstash/1.5/debian stable main' |  tee /etc/apt/sources.list.d/logstash.list
sudo apt-get update
sudo apt-get install -y logstash apache2 elasticsearch

sudo service logstash stop
sudo update-rc.d -f logstash remove
sudo update-rc.d elasticsearch defaults

sudo cat <<EOF >> /etc/elasticsearch/elasticsearch.yaml
http.cors.allow-origin: "/.*/"
http.cors.enabled: true
EOF

sudo cat << EOF >> /etc/default/elasticsearch
ES_HEAP_SIZE=1g
EOF

sudo service elasticsearch restart

wget http://download.elasticsearch.org/kibana/kibana/kibana-latest.tar.gz
tar -xzf kibana-latest.tar.gz
mv kibana-latest/* /var/www/html/
SCRIPT

$moloch = <<SCRIPT

sudo cat <<IP4 >> /etc/network/interfaces

auto eth1
iface eth1 inet static
address 192.168.56.196
netmask 255.255.255.0
IP4

sudo ifup eth1

sudo apt-get update
sudo apt-get -y install openjdk-7-jre-headless

sudo mkdir -p /data/moloch
cd /data/moloch
wget -q https://github.com/aol/moloch/archive/v0.11.5.tar.gz
tar -xzf v0.11.5.tar.gz
cd moloch-0.11.5
echo -e 'no\n512M\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n' | sudo ./easybutton-singlehost.sh
sudo pkill -9 java

sudo wget -O - http://packages.elasticsearch.org/GPG-KEY-elasticsearch | apt-key add -
sudo echo 'deb http://packages.elasticsearch.org/elasticsearch/1.7/debian stable main' | tee /etc/apt/sources.list.d/elasticsearch.list

sudo apt-get update
sudo apt-get install -y elasticsearch

sudo cat << EOF >> /etc/default/elasticsearch
ES_HEAP_SIZE=1g
EOF

sudo service elasticsearch restart
sudo update-rc.d elasticsearch defaults

SCRIPT

$host_private = <<SCRIPT

cat <<KEY > /home/vagrant/.ssh/id_rsa
-----BEGIN RSA PRIVATE KEY-----
MIIEogIBAAKCAQEAxMqVn7fWgXlSUBI8dI6783PFcguNx2VbkZIWyDF9lCFx/HFV
nVMsKZLL8bv/pT6PQf8kOSTH/xU0OInaYktAc4EpptPmluA0q+PKRxmGQowYtr24
LNfkL3H534ASNeMQcbVfbsAAF2i9y9LA/JLHPYRllD2qQuU68ZMmTwYeMTskJu/3
5Q5YWtiW4km3t6fCCZCHLActxfzcP438EW6Iwqn4TpE2MKRzEh1a31tZjyZKr5OQ
03z06Gyp37MLALCsspGGrv38DoboZe1YQntYIhRYRKoxEADK28enObYJXyH6zg5J
UmxgBQvX9Jh9qqt5aUA5YhbpgKf4iAJ7d5TMnQIDAQABAoIBAFMbbvblr2w8bTut
h+R9hvh4cvEH2hdUQciHVqGy7OLLARVoU4y+XE8uVHzBNWR2uA9aDdUoKGIcdVJP
PW/3cb+V055FrQMYqoXRDFLcf6vI+ILsOkSN5Cr5SlpN/uLNAtvSifv+j8tTC5xx
Y9kGr6fWKwPgyu+3WR4+U5ZZ8hQ9tQjK0QkQOyxlXK6aZCdw1ggc6h7w9E4CnkzG
6ISRKmTICAicxxSgM6xr7cLMTPN7S4jgxmjNqKTmM7pQWuQU4QaMObB6/LFIzlnY
jmbvxjXGypAAI+axDYLw3nC8JBuOh+5+4bEgXDpk7KLblqE11xJ0YTekHYmYGqci
pscTswECgYEA57ZC5+criPv19mdofG2W570uqib39Mc0Aisf0g6ga4MKkmOsiNOW
ugSDc06tRUbRNkH52JZ+dOKqBhdqvVdsz3e/TRafv2pRi4mu/Y3o3gnA62IZFfaz
+eADaw3WJwMP+99HYohsdcluQdNu0OEdduMW8NiuOhr0+jpJ1J4uG10CgYEA2WtE
M6sb9ftTy2OWuCtNSPOIEjS/3lAbfmm8sKu98kaL8FJs4TjWxxjx4BpxPOr5aqHl
BIX0OpvROtKmghomGR3gg2srJAaefx+4TrRBjRtlj4IPR6yLUFAcF9MEloG/QQeh
2vV0H4WXlUyRoq3uYzwWLUJ2NNMnC5fOtBjbokECgYA9WmRC1VIQtm59LQpckAP6
HnyhrynOlYRu4o5NZ3QQo6UD+AJyRFxPquxHdtioVEUHMdb/A3I+btoIPOEVe3Wj
RZjQx6HK5FLtOKquFopHaJu9d78esrEbA7bD/OjscYIk9g0HyQm28nwQT/SyuDi+
BwlHAoi3d/XP3+k2tB+PPQKBgGKZc8eezMJkJR8y3dJNyPHRh58CDxVp7N4KY8kX
ScAK4EGvj7MgDL8j/+Uq+LmwskX6f5rqiNTffyaXC24rH6X6V6whuOHQoqZyIyqG
MsgkaY2IZReTF2bnvaXMS+NZmfuK04syD2SQOCs8GzvUdyzHviLuZh8UtztZsCMa
tthBAoGATo70wDB/GC2Vpmnn4KfhCAf17NrtzCXbX4fdD3e2lJ3Ut7gaLppb/lZH
o2H+QfHjykHQ/jRHfYWmiHTgm3CrOPFvtsppf3VZELoiMH35NpYpjZ39HQhYVzmE
YyFL/MTtupbANcuPb0fjmJEV3nISvBQ+b6i+aUAi4vCd6CrRqJo=
-----END RSA PRIVATE KEY-----
KEY

sudo chmod 0600 /home/vagrant/.ssh/id_rsa
sudo chown vagrant:vagrant /home/vagrant/.ssh/id_rsa

sudo ssh-keygen -q -t rsa -f /root/.ssh/id_rsa -N ""

SCRIPT

$host_public = <<SCRIPT

cat <<KEY >> /home/vagrant/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDEypWft9aBeVJQEjx0jrvzc8VyC43HZVuRkhbIMX2UIXH8cVWdUywpksvxu/+lPo9B/yQ5JMf/FTQ4idpiS0BzgSmm0+aW4DSr48pHGYZCjBi2vbgs1+QvcfnfgBI14xBxtV9uwAAXaL3L0sD8ksc9hGWUPapC5TrxkyZPBh4xOyQm7/flDlha2JbiSbe3p8IJkIcsBy3F/Nw/jfwRbojCqfhOkTYwpHMSHVrfW1mPJkqvk5DTfPTobKnfswsAsKyykYau/fwOhuhl7VhCe1giFFhEqjEQAMrbx6c5tglfIfrODklSbGAFC9f0mH2qq3lpQDliFumAp/iIAnt3lMyd vagrant@host
KEY

SCRIPT

Vagrant.configure(2) do |config|
    
    config.vm.provider :virtualbox do |vb|
        vb.customize ["modifyvm", :id, "--memory", "1024"]
        vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
        vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
    end
    config.vm.define "router1" do |router1|
        router1.vm.network :forwarded_port, 
            guest: 2022, 
            host: 2021, 
            id: 'ssh'
        router1.ssh.port = "2021"
        router1.ssh.guest_port = "2022"
        router1.vm.box = "exfil_router"
        router1.vm.hostname = "router1"
        # eth1
        router1.vm.network "private_network", 
            ip: "192.168.11.1", 
            virtualbox__intnet: "victim_LAN", 
            auto_config: false
        # eth2
        router1.vm.network "private_network", 
            ip: "172.10.10.21", 
            virtualbox__intnet: "pub_SINET", 
            auto_config: false
        router1.vm.network "private_network", 
            ip: "192.168.56.191", 
            auto_config: false
        router1.vm.provision "shell", inline: $router1_persist
    end
    config.vm.define "router2" do |router2|
        router2.vm.network :forwarded_port, 
            guest: 2022, 
            host: 2022, 
            id: 'ssh'
        router2.ssh.port = "2022"
        router2.ssh.guest_port = "2022"
        router2.vm.box = "exfil_router"
        router2.vm.hostname = "router2"
        # eth1
        router2.vm.network "private_network", 
            ip: "192.168.12.1", 
            virtualbox__intnet: "cnc_SINET", 
            auto_config: false
        # eth2
        router2.vm.network "private_network", 
            ip: "172.10.10.22", 
            virtualbox__intnet: "pub_SINET", 
            auto_config: false
        router2.vm.network "private_network", 
            ip: "192.168.56.192", 
            auto_config: false
        router2.vm.provision "shell", 
            inline: $router2_persist
        router2.vm.provision "shell", 
            inline: $isp
    end
    config.vm.define "host" do |host|
        host.vm.network :forwarded_port, 
            guest: 2022, 
            host: 2023, 
            id: 'ssh'
        host.ssh.port = "2023"
        host.ssh.guest_port = "2022"
        host.vm.box = "exfil_kali"
        # eth1, ip4 is not configured by vagrant (see inline)
        host.vm.network "private_network", 
            ip: "192.168.11.11", 
            virtualbox__intnet: "victim_LAN", 
            auto_config: false
        host.vm.network "private_network", 
            ip: "192.168.56.193", 
            auto_config: false
        host.vm.provision "shell", 
            inline: $host_persist
        host.vm.provision "shell", 
            inline: $host_private
    end
    config.vm.define "cnc" do |cnc|
        cnc.vm.network :forwarded_port, 
            guest: 2022, 
            host: 2024, 
            id: 'ssh'
        cnc.ssh.port = "2024"
        cnc.ssh.guest_port = "2022"
        cnc.vm.box = "exfil_kali"
        # eth1, ip4 is not configured by vagrant (see inline)
        cnc.vm.network "private_network", 
            ip: "192.168.12.12", 
            virtualbox__intnet: "cnc_SINET", 
            auto_config: false
        cnc.vm.network "private_network", 
            ip: "192.168.56.194", 
            auto_config: false
        cnc.vm.provision "shell", 
            inline: $cnc_persist
        cnc.vm.provision "shell", 
            inline: $host_public
    end
    config.vm.define "tap" do |tap|
        tap.vm.box = "ubuntu/trusty64"
        tap.vm.hostname = "tap"
        # eth1, no address assigned for packet capture
        tap.vm.network "private_network", 
            ip: "0.0.0.0", 
            virtualbox__intnet: "pub_SINET"
        tap.vm.network "private_network", 
            ip: "192.168.56.195", 
            auto_config: false
        config.vm.provider :virtualbox do |box|
            # nicpromisc2 = promisc on eth1
            box.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
            box.customize ["modifyvm", :id, "--memory", "2048"]
            box.customize ["modifyvm", :id, "--cpus", "2"]
        end
        tap.vm.provision "shell", 
            inline: $monitoring
        tap.vm.provision "shell", 
            inline: $bro
        tap.vm.provision "shell", 
            inline: $suricata
        tap.vm.provision "shell", 
            inline: $elk
        tap.vm.provision "shell", 
            inline: $snort
    end
    config.vm.define "moloch" do |moloch|
        moloch.vm.box = "ubuntu/trusty64"
        moloch.vm.hostname = "moloch"
        # eth1, no address assigned for packet capture
        moloch.vm.network "private_network", 
            ip: "192.168.56.196",
            auto_config: false
        config.vm.provider :virtualbox do |box|
            # nicpromisc2 = promisc on eth1
            box.customize ["modifyvm", :id, "--memory", "2048"]
            box.customize ["modifyvm", :id, "--cpus", "2"]
        end
        moloch.vm.provision "shell", 
            inline: $moloch
    end
end