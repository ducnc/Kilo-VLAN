#!/bin/bash -ex
source config.cfg

apt-get install lvm2 -y

echo "########## Create Physical Volume and Volume Group (in sdb disk ) ##########"

pvcreate /dev/vdb
vgcreate cinder-volumes /dev/vdb

#
echo "########## Install CINDER ##########"
sleep 3
apt-get install -y cinder-api cinder-scheduler cinder-volume iscsitarget open-iscsi iscsitarget-dkms python-cinderclient


echo "########## Configuring for cinder.conf ##########"

filecinder=/etc/cinder/cinder.conf
test -f $filecinder.orig || cp $filecinder $filecinder.orig
rm $filecinder
cat << EOF > $filecinder
[DEFAULT]
rpc_backend = rabbit
my_ip = $CON_MGNT_IP
enabled_backends = lvm

glance_host = $CON_MGNT_IP

rootwrap_config = /etc/cinder/rootwrap.conf
api_paste_confg = /etc/cinder/api-paste.ini
iscsi_helper = tgtadm
volume_name_template = volume-%s
volume_group = cinder-volumes
verbose = True
auth_strategy = keystone
state_path = /var/lib/cinder
lock_path = /var/lock/cinder
volumes_dir = /var/lib/cinder/volumes


[database]
connection = mysql://cinder:$CINDER_DBPASS@$CON_MGNT_IP/cinder

[oslo_messaging_rabbit]
rabbit_host = $CON_MGNT_IP
rabbit_userid = openstack
rabbit_password = $RABBIT_PASS

[lvm]
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_group = cinder-volumes
iscsi_protocol = iscsi
iscsi_helper = tgtadm
 
[keystone_authtoken]
auth_uri = http://$CON_MGNT_IP:5000
auth_url = http://$CON_MGNT_IP:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = cinder
password = $CINDER_PASS

[oslo_concurrency]
lock_path = /var/lock/cinder

EOF

#sed -r -e 's#(filter = )(\[ "a/\.\*/" \])#\1[ "a\/sda1\/", "a\/sdb\/", "r/\.\*\/"]#g' /etc/lvm/lvm.conf
sed -r -i 's#(filter = )(\[ "a/\.\*/" \])#\1["a\/vdb\/", "r/\.\*\/"]#g' /etc/lvm/lvm.conf

# Grant permission for cinder
chown cinder:cinder $filecinder

echo "########## Syncing Cinder DB ##########"
sleep 3
su -s /bin/sh -c "cinder-manage db sync" cinder

echo "########## Restarting CINDER service ##########"
sleep 3
service cinder-api restart
service cinder-scheduler restart
service cinder-volume restart

echo "########## Finish setting up CINDER !!! ##########"
