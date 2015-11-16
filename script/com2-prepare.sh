#!/bin/bash -ex
#

source config.cfg

iphost=/etc/hosts
test -f $iphost.orig || cp $iphost $iphost.orig
rm $iphost
touch $iphost
cat << EOF >> $iphost
127.0.0.1       localhost
$CON_MGNT_IP    $HOST_NAME
$COM1_MGNT_IP      compute1
$COM2_MGNT_IP      compute2
EOF

########
echo "############ Cai dat NTP ############"
########
#Cai dat NTP va cau hinh can thiet 
apt-get install ntp -y
apt-get install python-mysqldb -y


########
echo "############ Cau hinh NTP ############"
sleep 10
########
# Cau hinh ntp
mv /etc/ntp.conf /etc/ntp.conf.bka
cat /etc/ntp.conf.bka | grep -v ^# | grep -v ^$ >> /etc/ntp.conf
#
sed -i 's/server 0.ubuntu.pool.ntp.org/ \
#server 0.ubuntu.pool.ntp.org/g' /etc/ntp.conf

sed -i 's/server 1.ubuntu.pool.ntp.org/ \
#server 1.ubuntu.pool.ntp.org/g' /etc/ntp.conf

sed -i 's/server 2.ubuntu.pool.ntp.org/ \
#server 2.ubuntu.pool.ntp.org/g' /etc/ntp.conf

sed -i 's/server 3.ubuntu.pool.ntp.org/ \
#server 3.ubuntu.pool.ntp.org/g' /etc/ntp.conf

sed -i "s/server ntp.ubuntu.com/server $CON_MGNT_IP iburst/g" /etc/ntp.conf

# Cai cac goi can thiet cho compute 
apt-get -y install nova-compute sysfsutils
apt-get install libguestfs-tools -y

echo "net.ipv4.conf.all.rp_filter=0" >> /etc/sysctl.conf
echo "net.ipv4.conf.default.rp_filter=0" >> /etc/sysctl.conf
sysctl -p

#dpkg-statoverride --update --add root root 0644 /boot/vmlinuz-$(uname -r)
#touch /etc/kernel/postinst.d/statoverride

#
#cat << EOF >> /etc/kernel/postinst.d/statoverride
#"#!/bin/sh"
#echoversion="$1"
# passing the kernel version is required
#[ -z "${version}" ] && exit 0
#dpkg-statoverride --update --add root root 0644 /boot/vmlinuz-${version}
#EOF

#chmod +x /etc/kernel/postinst.d/statoverride


########
echo "############ Cau hinh nova.conf ############"
sleep 5
########
#/* Sao luu truoc khi sua file nova.conf
filenova=/etc/nova/nova.conf
test -f $filenova.orig || cp $filenova $filenova.orig

#Chen noi dung file /etc/nova/nova.conf vao 
cat << EOF > $filenova
[DEFAULT]

rpc_backend = rabbit
auth_strategy = keystone


#fix loi instances fails to allocate the network
vif_plugging_is_fatal = False
vif_plugging_timeout = 0


my_ip = $COM2_MGNT_IP
vnc_enabled = True
vncserver_listen = 0.0.0.0
vncserver_proxyclient_address = $COM2_MGNT_IP
novncproxy_base_url = http://$CON_MGNT_IP:6080/vnc_auto.html


# Cho phep thay doi kich thuoc may ao
allow_resize_to_same_host=True
scheduler_default_filters=AllHostsFilter

# Cho phep chen password khi khoi tao
libvirt_inject_password = True
enable_instance_password = True
libvirt_inject_key = true
libvirt_inject_partition = -1

network_api_class = nova.network.neutronv2.api.API
security_group_api = neutron
linuxnet_interface_driver = nova.network.linux_net.LinuxOVSInterfaceDriver
firewall_driver = nova.virt.firewall.NoopFirewallDriver


dhcpbridge_flagfile=/etc/nova/nova.conf
dhcpbridge=/usr/bin/nova-dhcpbridge
logdir=/var/log/nova
state_path=/var/lib/nova
# lock_path=/var/lock/nova
force_dhcp_release=True
libvirt_use_virtio_for_bridges=True
# verbose=True
ec2_private_dns_show_ip=True
api_paste_config=/etc/nova/api-paste.ini
enabled_apis=ec2,osapi_compute,metadata

[oslo_messaging_rabbit]
rabbit_host = $CON_MGNT_IP
rabbit_userid = openstack
rabbit_password = $RABBIT_PASS


[oslo_concurrency]
lock_path = /var/lock/nova


[neutron]
url = http://$CON_MGNT_IP:9696
auth_strategy = keystone
admin_auth_url = http://$CON_MGNT_IP:35357/v2.0
admin_tenant_name = service
admin_username = neutron
admin_password = $NEUTRON_PASS

[keystone_authtoken]
auth_uri = http://$CON_MGNT_IP:5000
auth_url = http://$CON_MGNT_IP:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = nova
password = $NOVA_PASS

[glance]
host = $CON_MGNT_IP


EOF

# Xoa file sql mac dinh
rm /var/lib/nova/nova.sqlite


# fix loi libvirtError: internal error: no supported architecture for os type 'hvm'
echo 'kvm_intel' >> /etc/modules
 
# Khoi dong lai nova
service nova-compute restart
service nova-compute restart

########
echo "############ Cai dat neutron agent ############"
sleep 5
########
# Cai dat neutron agent
apt-get install neutron-common neutron-plugin-ml2 neutron-plugin-openvswitch-agent openvswitch-datapath-dkms -y

##############################
echo "############ Cau hinh neutron.conf ############"
sleep 5
#############################
comfileneutron=/etc/neutron/neutron.conf
test -f $comfileneutron.orig || cp $comfileneutron $comfileneutron.orig
rm $comfileneutron
#Chen noi dung file /etc/neutron/neutron.conf
 
cat << EOF > $comfileneutron
[DEFAULT]
verbose = True

rpc_backend = rabbit
auth_strategy = keystone

core_plugin = ml2
service_plugins = router
allow_overlapping_ips = True

notify_nova_on_port_status_changes = True
notify_nova_on_port_data_changes = True
nova_url = http://$CON_MGNT_IP:8774/v2


[matchmaker_redis]
[matchmaker_ring]
[quotas]
[agent]
root_helper = sudo /usr/bin/neutron-rootwrap /etc/neutron/rootwrap.conf

[keystone_authtoken]
auth_uri = http://$CON_MGNT_IP:5000
auth_url = http://$CON_MGNT_IP:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = neutron
password = $NEUTRON_PASS



[database]
connection = mysql://neutron:$NEUTRON_DBPASS@$CON_MGNT_IP/neutron


[nova]
auth_url = http://$CON_MGNT_IP:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
region_name = RegionOne
project_name = service
username = nova
password = $NOVA_PASS

[oslo_concurrency]
lock_path = \$state_path/lock
[oslo_policy]
[oslo_messaging_amqp]
[oslo_messaging_qpid]

[oslo_messaging_rabbit]
rabbit_host = $CON_MGNT_IP
rabbit_userid = openstack
rabbit_password = $RABBIT_PASS

EOF
#

########
echo "############ Cau hinh ml2_conf.ini ############"
sleep 5
########
comfileml2=/etc/neutron/plugins/ml2/ml2_conf.ini
test -f $comfileml2.orig || cp $comfileml2 $comfileml2.orig
rm $comfileml2
touch $comfileml2
#Chen noi dung file  vao /etc/neutron/plugins/ml2/ml2_conf.ini
cat << EOF > $comfileml2
[ml2]
type_drivers = flat,vlan,gre
tenant_network_types = vlan,gre
mechanism_drivers = openvswitch

[ml2_type_flat]

[ml2_type_vlan]
network_vlan_ranges = physnet1:100:600

[ml2_type_gre]

[ml2_type_vxlan]

[securitygroup]
enable_security_group = True
enable_ipset = True
firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

[ovs]
tenant_network_type = vlan
bridge_mappings = physnet1:br-eth1

EOF

# Khoi dong lai OpenvSwitch
########
echo "############ Khoi dong lai OpenvSwitch ############"
sleep 5
########
service openvswitch-switch restart


########
echo "############ Tao integration bridge ############"
sleep 5
########
# Tao integration bridge
ovs-vsctl add-br br-int 
ovs-vsctl add-br br-eth1
ovs-vsctl add-port br-eth1 eth1


# fix loi libvirtError: internal error: no supported architecture for os type 'hvm'
echo 'kvm_intel' >> /etc/modules

##########
echo "############ Khoi dong lai Compute ############"
sleep 5

########
# Khoi dong lai Compute
service nova-compute restart
service nova-compute restart

########
echo "############ Khoi dong lai Openvswitch agent ############"
sleep 5
########
# Khoi dong lai Openvswitch agent
service neutron-plugin-openvswitch-agent restart
service neutron-plugin-openvswitch-agent restart

echo "########## TAO FILE CHO BIEN MOI TRUONG ##########"
sleep 5
echo "export OS_USERNAME=admin" > admin-openrc.sh
echo "export OS_PASSWORD=$ADMIN_PASS" >> admin-openrc.sh
echo "export OS_TENANT_NAME=admin" >> admin-openrc.sh
echo "export OS_AUTH_URL=http://$HOST_NAME:35357/v2.0" >> admin-openrc.sh

########
echo "############ KIEM TRA LAI NOVA va NEUTRON ############"
sleep 5
########
source admin-openrc.sh
nova-manage service list
neutron agent-list
