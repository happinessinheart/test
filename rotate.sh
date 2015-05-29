#!/bin/bash

# this script is used to rotate the lease record file 

# (default to /tmp/lease.record) for every week

if [ $(date +%w) != 6 ] ;then

	exit 0 # only work at Sunday 

else

 . /etc/sysconfig/lease_watch.conf

 [ -z "$target_file" ] && target_file=/tmp/lease.record

 [ ! -e "$target_file" ] && echo "Error! No lease record file found ,or Invalid lease record file" && exit 1
	
 [ ! -f "$target_file" ] && echo "Error! Invalid lease record file" && exit 1

 cp -f $target_file $target_file.$(date +'%Y-%m-%d') 

 rm -f $target_file

 pkill -9 -f "tail --follow=name /var/lib/dhcp/dhcpd.leases" > /dev/null

 usleep  100

 /myscript/dhcp-statistics/lease_watch.sh

fi

 # Determine if the crontab entry set

 if ! $(crontab -l |grep '/myscript/dhcp-statistics/lease_watch.sh' >/dev/null) ;then

	tmpfile=$(mktemp /tmp/crontab.XXXXXX)

	crontab -l |grep -v '^#' > $tmpfile

	echo '10 0 15 * * /myscript/dhcp-statistics/rotate.sh >/dev/null' >> $tmpfile

	crontab $tmpfile

	rm -f $tmpfile
fi
