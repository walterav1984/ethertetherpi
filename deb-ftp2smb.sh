#!/bin/bash
#
# deb-f2s.sh
#
# This script configures a debian stretch installation for ftp&smb server usage.
# The bonjour samba share has readonly access to all ftp users their chroots! 
# For passive ftp usage adjust pasv_min/max_port and pasv_address, don't forget  
# firewall/nat rules (1 on 1 portmap) on server side router. Minimal 2 ports are
# needed for ftp, communication(21) and data(random active)/(fixed 443 passive)!

#setup samba variables
F2SSMBWKGRP="WORKGROUP"
F2SSMBUSER0="smbuserz"
F2SSMBPASS0="smbpassz"
F2SSMBSHARE="ftp2smbshare"          #max12char
F2SHOSTNAME="ftp2smbvmnas"          #required for netbios name!

#setup ftp user/password
echo "#edit/add/remove ftp username/password =sign seperated max of 8char!!!
ftpuser1=passwrdA
ftpuser2=passwrdB
ftpuser3=passwrdC
" > ftpusers.txt

#default ftp virtual(parent)user
F2SFTPUSER0="vuvsftpd"             
F2SFTPPASS0="max8char"

#prepare system
sudo apt-get update
sudo apt-get -y install ntp net-tools nmap tftp samba avahi-daemon avahi-discover libnss-mdns avahi-utils vsftpd apache2-utils libpam-pwdfile curl python3

sudo sed -i "s/$HOSTNAME/$F2SHOSTNAME/g" /etc/hosts
sudo sed -i "s/$HOSTNAME/$F2SHOSTNAME/g" /etc/hostname

#smb user setup
sudo useradd --home /home/$F2SSMBUSER0 --gid nogroup -m --shell /bin/false $F2SSMBUSER0 #does this user need a unix password?
echo -e "$F2SSMBPASS0\n$F2SSMBPASS0" | sudo tee | sudo smbpasswd -s -a $F2SSMBUSER0 #change smb $pass

#smb server setup
sudo tee /etc/samba/smb.conf << _EOF_
[global]
    wins support = yes
    local master = yes
    preferred master = yes
    workgroup = RSMBWKGRP
    netbios name = RUPCNETBIOS
    lanman auth = no
    ntlm auth = yes
    client lanman auth = no

[RSMBSHARE]
    comment = "ftp2smb debian based vm share test"
    path = /home/RSMBUSER0
    browseable = yes
    writeable = yes
    create mask = 0600
    directory mask = 0700
    spotlight = yes
    guest ok= no
    valid users = RSMBUSER0
_EOF_

sudo sed -i "s|RSMBSHARE|$F2SSMBSHARE|g" /etc/samba/smb.conf
sudo sed -i "s|RSMBUSER0|$F2SSMBUSER0|g" /etc/samba/smb.conf
sudo sed -i "s|RSMBWKGRP|$F2SSMBWKGRP|g" /etc/samba/smb.conf
#convert lower to upper case naming required for NETBIOS
UPCNETBIOS=$(echo $F2SHOSTNAME | sed -e 's/\(.*\)/\U\1/' $F2SHOSTNAME -)
sudo sed -i "s|RUPCNETBIOS|$UPCNETBIOS|g" /etc/samba/smb.conf

#testparm #will test smb.conf setings
sudo systemctl restart smbd nmbd

#smb bonjour / zeroconf / avahi discovery 
sudo tee /etc/avahi/services/smb.service <<_EOF_
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
 <name replace-wildcards="yes">%h</name>
 <service>
   <type>_smb._tcp</type>
   <port>445</port>
 </service>
 <service>
   <type>_device-info._tcp</type>
   <port>0</port>
   <txt-record>model=RackMac</txt-record>
 </service>
</service-group>
_EOF_

sudo systemctl restart avahi-daemon

#wsdd Windows Network Discovery
mkdir ~/wsdd
cd ~/wsdd
curl -O https://raw.githubusercontent.com/christgau/wsdd/master/src/wsdd.py
sudo sed -i 's|exit 0|/usr/bin/python3 /home/'$USER'/wsdd/wsdd.py \& \nexit 0|' /etc/rc.local
sudo systemctl restart rc.local.service

#ftp user setup
sudo useradd --home /home/$F2SFTPUSER0 --gid nogroup -m --shell /bin/false $F2SFTPUSER0 #does this user need a unix password?
#sudo useradd -p `openssl passwd -1 ftp2smb` -m --shell /bin/false ftpuser #ftp2smb will be ftppassword

#ftp create users "for every line/user do script"
userlist='ftpusers.txt'
filelines=`cat $userlist | grep -v '#'`
printf "passzero" | sudo htpasswd -i -c -d /etc/ftpd.passwd userzero
for line in $filelines ; do
    RUSER=$(echo $line | sed -e 's/=.*//' -)
    RPASS=$(echo $line | sed -e 's/.*=//' -)
    printf "$RPASS" | sudo htpasswd -i -d /etc/ftpd.passwd $RUSER #d/i
    sudo mkdir -p /home/$F2SFTPUSER0/$RUSER
    sudo chown -R $F2SFTPUSER0:nogroup /home/$F2SFTPUSER0/$RUSER #not needed since in user0hf?
    sudo chmod -R +w /home/$F2SFTPUSER0/$RUSER
    sudo mkdir /home/$F2SSMBUSER0/$RUSER #create folder?
    sudo chown -R $F2SSMBUSER0:nogroup /home/$F2SSMBUSER0/$RUSER
    echo "/home/$F2SFTPUSER0/$RUSER /home/$F2SSMBUSER0/$RUSER none defaults,bind 0 0" | sudo tee -a /etc/fstab
    #sudo mount --bind /home/$F2SFTPUSER0/$RUSER /home/$F2SSMBUSER0/$RUSER #after reboot/fstab?
done

#ftp configure vsftpd server
sudo sed -i "s/listen=NO/listen=YES/g" /etc/vsftpd.conf #ipv4 only
sudo sed -i "s/listen_ipv6=YES/listen_ipv6=NO/g" /etc/vsftpd.conf #ipv6 disable
#anonymous_enable=NO #default
#local_enable=YES #default
sudo sed -i "s/#write_enable=YES/write_enable=YES/g" /etc/vsftpd.conf
sudo sed -i "s/#local_umask=022/local_umask=022/g" /etc/vsftpd.conf
sudo sed -i "s/#chroot_local_user=YES/chroot_local_user=YES/g" /etc/vsftpd.conf #2 instances!
echo "allow_writeable_chroot=YES" | sudo tee -a /etc/vsftpd.conf #otherwise 500 error
sudo sed -i "s/#nopriv_user=ftpsecure/nopriv_user=$F2SFTPUSER0/g" /etc/vsftpd.conf #500 OOPS error user not found
echo "guest_username=$F2SFTPUSER0" | sudo tee -a /etc/vsftpd.conf #
echo "virtual_use_local_privs=YES" | sudo tee -a /etc/vsftpd.conf #
echo "guest_enable=YES" | sudo tee -a /etc/vsftpd.conf #
echo "user_sub_token=\$USER" | sudo tee -a /etc/vsftpd.conf #
echo "local_root=/home/$F2SFTPUSER0/\$USER" | sudo tee -a /etc/vsftpd.conf #
echo "hide_ids=YES" | sudo tee -a /etc/vsftpd.conf #
#pasv_max_port=443 #this port is used for data besides default port 21 map 1on1 
#pasv_min_port=443 #single data port works add firewall/nat rule for 21/443 pasv
#pasv_address=publicip #public ip of ftp server not nat/local subnet ip address

echo "auth required pam_pwdfile.so pwdfile /etc/ftpd.passwd" | sudo tee /etc/pam.d/vsftpd #
echo "account required pam_permit.so" | sudo tee -a /etc/pam.d/vsftpd #

sudo systemctl restart vsftpd

exit 0
