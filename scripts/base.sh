#!/bin/bash

# Disable the broken repositories.
truncate --size=0 /etc/yum.repos.d/CentOS-Media.repo /etc/yum.repos.d/CentOS-Vault.repo

# Ensure a nameserver is being used that won't return an IP for non-existent domain names.
printf "\nnameserver 4.2.2.1\n" > /etc/resolv.conf

# Set the local hostname to resolve properly.
printf "\n127.0.0.1	magma.builder\n\n" >> /etc/hosts

# Update the base install first.
yum --assumeyes update

# Packages needed beyond a minimal install to build and run magma.
yum --assumeyes install valgrind valgrind-devel check check-devel ncurses-devel gcc-c++ libstdc++-devel gcc cloog-ppl cpp glibc-devel glibc-headers kernel-headers libgomp mpfr ppl perl perl-Module-Pluggable perl-Pod-Escapes perl-Pod-Simple perl-libs perl-version patch sysstat perl-Time-HiRes

# Install the libbsd packages from the EPEL repository, which DSPAM relies upon for the strl functions.
# The entropy daemon is optional, but improves the availability of entropy, which makes magma launch 
# and complete her unit tests faster.
yum --assumeyes --enablerepo=extras install epel-release
yum --assumeyes install libbsd libbsd-devel haveged

# The daemon services magma relies upon. 
yum --assumeyes install libevent memcached mysql mysql-server perl-DBI perl-DBD-MySQL 

# Packages used to retrieve the magma code, but aren't required for building/running the daemon.
yum --assumeyes install wget git rsync perl-Git perl-Error

# Packages used during the provisioning process, and could be removed later.
yum --assumeyes install sudo dmidecode yum-utils

# Run update a second time, just in case it failed the first time. Mirror timeoutes and cosmic rays 
# often interupt the the provisioning process.
yum --assumeyes --disablerepo=epel update

# Enable and start the daemons.
chkconfig mysqld on
chkconfig haveged on
chkconfig memcached on
service mysqld start
service haveged start
service memcached start

# Disable IPv6 and the iptables module used to firewall IPv6.
chkconfig ip6tables off
printf "\n\nnet.ipv6.conf.all.disable_ipv6 = 1\n" >> /etc/sysctl.conf

# Close a potential security hole.
chkconfig netfs off

# Create the clamav user to avoid spurious errors.
useradd clamav

# Setup the mysql root account with a random password.
export PRAND=`openssl rand -base64 18`
mysqladmin --user=root password "$PRAND"

# Allow the root user to login to mysql as root by saving the randomly generated password.
printf "\n\n[mysql]\nuser=root\npassword=$PRAND\n\n" >> /root/.my.cnf 

# Create the mytool user and grant the required permissions.
mysql --execute="CREATE USER mytool@localhost IDENTIFIED BY 'aComplex1'"
mysql --execute="GRANT ALL ON *.* TO mytool@localhost"

# Setup the memory locking limits.
printf "\n*    soft    memlock    1000000" >> /etc/security/limits.conf
printf "\n*    hard    memlock    1000000" >> /etc/security/limits.conf

# Set the timezone to Pacific time.
printf "ZONE=\"America/Los_Angeles\"\n" > /etc/sysconfig/clock

# Tweak sshd to prevent reverse DNS lookups which speeds up the login process.
echo 'UseDNS no' >> /etc/ssh/sshd_config
