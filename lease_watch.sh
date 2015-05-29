#!/bin/bash

# Ver 2.0   

#
# this script is used to watch the /var/lib/dhcp/dhcpd.leases
#
# file continueslyand write everything into the target specified.
#
# The purpose is to keep a full copy of /var/lib/dhcp/dhcpd.leases,
#
# even /var/lib/dhcp/dhcpd.leases had been truncated
#


# Parameters

# 1. -s : specify the max size of target file .default to 2 MB
	
#              and the current content will be dump to a file.<from>-<to>

# 2. -f : specify the target file path ,default to /tmp/lease.record ,owned by root:root ,permission (rw-r--r--)

# Remove the lock file when the process die

# Main

# First check whether the /var/lib/dhcp/dhcpd.leases exists , or complain and exit

# Determine if any lease_watch process is running ,or exit quietly

# Determine if wether another lease_watch is running 

if [ -f /var/lock/subsys/lease_watch ] && $(pgrep -f "tail -n 13 --follow=name /var/lib/dhcp/dhcpd.leases" > /dev/null)  ;then

	echo "Error! Another lease_watch is running!"

	exit 1

elif [ -f /var/lock/subsys/lease_watch ] && ! $(pgrep -f "tail -n 13 --follow=name /var/lib/dhcp/dhcpd.leases" >/dev/null) ;then

	rm -f /var/lock/subsys/lease_watch # remove the old lock file

fi



if [ ! -e /var/lib/dhcp/dhcpd.leases ] || [ ! -f /var/lib/dhcp/dhcpd.leases ] ;then

	echo "Error! Cann't find the proper DHCP leases file" && exit 1

fi

while getopts ":s:f:" opt; do 
	
	case $opt in 
		
		s ) max_size=$OPTARG ;;

		f ) target_file=$OPTARG ;;
		
		\? ) echo "Usage: lease_watch [ -s <max_size> -f <target_file> ]" ; exit 1 ;;

	esac

done


# set default

[ -z "$max_size" ] && max_size=2097152

[ -z "$target_file" ] && target_file=/tmp/lease.record

# write these information into a config_file

config_file="/etc/sysconfig/lease_watch.conf"
[ ! -d /etc/sysconfig ] && mkdir -p /etc/sysconfig

#echo "max_size=$max_size" > $config_file

echo "target_file=$target_file" >> $config_file


# if the target file already exists and it's size is bigger then $max_size ,then rotate

if [ -e "$target_file" ] &&  [ ! -f "$target_file" ];then

	echo "Error! $target_file is a directory !" && exit 1
fi

if [ -e "$target_file" ] && [ -f "$target_file" ];then

	if [ $(stat --format="%s" "$target_file") -gt $max_size ] ;then

	        target_dir=$(dirname "$target_file")

        	filename=$(basename "$target_file")

	        cd $target_dir

        	cp "$filename" "${filename}.$(date  '+%Y-%m-%d')"

	        > $filename

        	echo "file truncated"

	fi

	tail -n 13 --follow=name /var/lib/dhcp/dhcpd.leases 2>/dev/null > $target_file &
	[ ! -d /var/lock/subsys/ ] && mkdir -p /var/lock/subsys/
	touch /var/lock/subsys/lease_watch


elif [ ! -e "$target_file" ]; then 

	touch $target_file

	chown root:root $target_file && chmod 644 $target_file

	tail -n 13 --follow=name /var/lib/dhcp/dhcpd.leases 2>/dev/null > $target_file  &

	touch /var/lock/subsys/lease_watch
fi
