#!/bin/bash

# Ver 1.0 ,Matainained by ailms@qq.com

# This script is used to analyse the lease record file , which 

# specified by the /etc/sysconfig/lease_watch.conf . It can provide

# the following functions :

# 1. -s , -t : specify the start and end time to analyse

# 2. -a : find out ip which status is "active" or "free" 

# 3. -m : list the current record for specified MAC address

# 4. -i : list the current record for specified ip address

# 5. -h : list the current record for specified hostname (which provied by the dhclient.conf )

# 6. -H : Display Usage

DHCP_CONFIG="/etc/dhcp/dhcpd.conf"

function preprocess 

{


local max_size target_file tmpfile pattern count field prefix line ip_addr lease_start lease_end current_state

local mac_addr client_hostname 

target_file=$1

tmpfile=$(mktemp /tmp/record.XXXXXX)  

# translate the $target_file into a easy-process format

pattern="^[[:blank:]]*lease|starts|ends|(binding state)|hardware|uid|ddns-rev-name|ddns-fwd-name"

sed -n '/^lease/,/^\}/p' $target_file |egrep  "$pattern" |tr -d "{}"|sed 's/^[[:blank:]]\+//' |sed 's/[[:blank:]]\+$//' |sed 's/\(^lease.*\)/\1\;/' |sed 's/;$//' > $tmpfile

# Read the tmpfile and generate a table

count=0

field=0

while read line ; do

   prefix=$(echo "$line" |cut -d ' ' -f 1)

	case $prefix in 

	  lease )  
		ip_addr=$(echo "$line" |cut -d ' ' -f 2)
		field=$((field +1))
		;;
	  starts ) 
		lease_start=$(echo "$line" |cut -d ' ' -f 3-)
		lease_start=$(date -d "${lease_start} 8 hours" +%s)
		field=$((field +1))
		;;
	  ends )
		lease_end=$(echo "$line" |cut -d ' ' -f 3-)
		lease_end=$(date -d "${lease_end} 8 hours" +%s)
		field=$((field +1))
		 ;;
	  binding )
		 current_state=$(echo "$line" |cut -d ' ' -f 3)
		 field=$((field +1))
		 ;;
	  hardware )
		 mac_addr=$(echo "$line" |cut -d ' ' -f 3)
		 field=$((field +1))
		 ;;
	  uid ) 
		client_hostname=$(echo "$line" |cut -d ' ' -f 2-|tr -d '"')
		field=$((field +1))
		;;
	esac

	if [ $field -eq 6 ];then

		echo "${ip_addr}|${lease_start}|${lease_end}|${current_state}|${mac_addr}|${client_hostname}" >> /tmp/lease.log

		field=0

        elif [ $field -eq 5 ];then

                echo "${ip_addr}|${lease_start}|${lease_end}|${current_state}|${mac_addr}" >> /tmp/lease.log

                field=0
	fi

	count=$((count +1 ))

done < $tmpfile  

rm -f $tmpfile

}

function find_active 

{

# Now find out what lease are active and what are free

local ip_list active_list free_list i lease mac_addr hostname

echo "All subnets : "
echo
sed -n '/^[[:blank:]]*subnet/,/^[[:blank:]]*range/p' $DHCP_CONFIG |egrep '(^[[:blank:]]*subnet)|(^[[:blank:]]*range)'|sed 's/^[[:blank:]]*//'|tr -d '{;'

echo "--------------------------------------------------------------------------"
echo

[ ! -e /tmp/lease.log ] || [ ! -f /tmp/lease.log ] && echo "Error! Cann't open the /tmp/lease.log file " && exit 1

ip_list=$(awk -F '|' '{print $1,$5,$6}' /tmp/lease.log |sort |uniq )

active_list=""

release_list=""
#echo $ip_list

ip_list=$(echo "$ip_list" |awk '{print $1}' |sort)

num_ip=`awk -F '|' '{print $1}' /tmp/lease.log |sort | uniq |wc -l`
#echo '$ip_list'|wc -l
#echo $ip_list
echo "ALL IP addr(# $num_ip) had been allocated : "
echo
ip_list=$(echo "$ip_list" |awk '{print $1}' |sort |uniq)
echo "$ip_list"
echo
echo "--------------------------------------------------------------------------"

for i in $ip_list ; do
	
	lease=$(grep "^$i" /tmp/lease.log |tail -n 1)

	lease_status=$(echo $lease|cut -d '|' -f 4)

	case $lease_status in 
	
		active )
			active_list="${active_list} $i" 
			mac_addr=$(echo $lease |cut -d '|' -f 5)
			hostname=$(echo $lease |cut -d '|' -f 6)
			active_list="${active_list}\t$mac_addr\t$hostname \\033[1;32m(ACTIVE)\\033[0;39m\n"
			;;
		free   )
			release_list="${release_list} $i (RELEASED)\n"
			;;
	esac
done
echo "IP Addr        | MAC                   | Hostname                         "                     
echo "--------------------------------------------------------------------------"
echo -e "$active_list"
echo -e "$release_list"  

#rm -f /tmp/lease.log

}


function filter {

 local mode value from to cmd filter_result title i start end status ip mac_addr hostname

 mode=$1
 value=$2
 from=$3
 to=$4

 [ -z "$mode" ] && echo "Error! You must specify one mode : mac | ip | hostname" && exit 1

 [ -z "$value" ] && echo "Error! You must specify a key value to query" && exit 1

 [ ! -e /tmp/lease.log ] || [ ! -f /tmp/lease.log ] && echo "Error! Cann't open /tmp/lease.log !" && exit 1

 # filter the proper time range from lease.log ,and deleete the duplicate record (maybe the  server relaod or restart)

 cmd="awk -F '|' '\$2 > $from && \$2 < $cmd $to'"

 filter_result=$(eval $cmd /tmp/lease.log |sort|uniq)

 # filter the proper record for the specified type and key value in the time range

 # and set the title

 case $mode in 

  mac ) 
	cmd="echo \"\$filter_result\"|awk -F '|' '\$5 ~ /$value/'" 
	title="IP addr         | Start             | End               | Status |\\033[1;32m MAC\\033[0;39m                | Hostname                       "
	;;
  ip  )
	cmd="echo \"\$filter_result\"|awk -F '|' '\$1 ~ /$value/'" 
        title="\\033[1;32mIP addr\\033[0;39m         | Start             | End               | Status | MAC                | Hostname                 "
	;;
  hostname)
	cmd="echo \"\$filter_result\"|grep \"$value\""
	title="IP addr         | Start             | End               | Status | MAC                | \\033[1;32mHostname\\033[0;39m    "
	;;
 esac	

 filter_result=$(eval $cmd)

 [ -z "$filter_result" ] && echo "Not Found!" && rm -f /tmp/lease.log && return
 echo
 echo -e "$title"
 
 echo "------------------------------------------------------------------------------------------------------------------------"

 for i in $filter_result; do
	 start=$(echo $i |cut -d '|' -f 2)
	 start=$(date -d "1970-01-01 $start sec utc" +'%Y-%m-%d %H:%M:%S')
	 end=$(echo $i |cut -d '|' -f 3)
	 end=$(date -d "1970-01-01 $end sec utc" +'%Y-%m-%d %H:%M:%S')
	 ip=$(echo $i|cut -d '|' -f 1)
	 status=$(echo $i|cut -d '|' -f 4)
	 mac_addr=$(echo $i |cut -d '|' -f 5) 
	 hostname=$(echo $i|cut -d '|' -f 6)
	 printf "%-16s%-20s%-20s%-11s%-20s%-20s\n" $ip "$start" "$end" $status $mac_addr $hostname
 done |more

 echo; echo

 rm -f /tmp/lease.log

} 



#++++++++++++++++++++++++++++++++++++++++++++++++  Main ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# Determine if lease_watch is running

if [ ! -e /var/lock/subsys/lease_watch ] && ! $(pgrep -f "tail -n 13 --follow=name /var/lib/dhcp/dhcpd.leases") ;then

	  echo "Error! lease_watch doesn't running at all!" && exit 1

fi

[ $# -eq 0 ] && echo "Usage : parse [-s <start>] [-t <end>]  -a | -m \"mac\" | -i \"ip\" | -H \"hostname\" " && exit 1 

mode_choose=0

while getopts ":s:t:am:i:H:hf:" opt ;do
	
	case $opt in 
	
	  s )
		 start_time=$OPTARG ;;
		
	  t )
		 end_time=$OPTARG  ;;

	  a )   mode_choose=$(( mode_choose + 1 ))
		mode=status ;;
		
	  m )	mode_choose=$(( mode_choose + 1 ))
		mode=mac
		mac_addr=$OPTARG;;

	  i )	mode_choose=$(( mode_choose + 1 ))
		mode=ip
		ip_addr=$OPTARG ;;

	  H)	mode_choose=$(( mode_choose + 1 ))
		mode=hostname
		hostname=$OPTARG;;

	  h)
		echo "Usage : parse [-s <start>] [-t <end>]  [ -f <lease.record>] -a | -m \"mac\" | -i \"ip\" | -H \"hostname\" " && exit 0 ;;

	  f)    target_file=$OPTARG ;;

	esac
	
done


# Determine if user choose more than one mode

[ $mode_choose -gt 1 ] && echo 'Error! Only one mode can choose from "-a" , "-i" , "-m" , "-h"' && exit 1

# Determine if user didn't choose any mode

[ $mode_choose -eq 0 ] && echo 'Error! You must choose one mode from "-a" ,"-i","-m","-h"' && exit 1

if [ -z "$start_time" ] ;then
       start_time=$(date -d "$(date +%Y-%m-%d) 0" +%s)      # default to the begin of today
else
       start_time=$(date -d "$start_time" +%s 2>/dev/null )
       [ -z "$start_time" ] && echo "Error! Invalid start time!" && exit 1
fi


if [ -z "$end_time" ] ;then
        end_time=$(date +%s) # deafult to now
else
        end_time=$(date -d "$end_time" +%s 2>/dev/null)
        [ -z "$end_time" ] && echo "Error! Invalid end time!" && exit 1
fi

if [ -z "$target_file" ] ;then

	target_file=/tmp/lease.record

elif [ ! -e  "$target_file" ] ;then
	
	echo "Error! file not found" 
	
	exit 1

elif [ ! -f "$target_file" ] ;then

	echo "Error! Invalid lease record file"

	exit 1

fi	 

# preprocess 

preprocess "$target_file"

case $mode in 

  status ) find_active ;;

  mac ) filter mac $mac_addr "$start_time" "$end_time" ;;

  ip ) filter ip "$ip_addr" "$start_time" "$end_time" ;;

  hostname ) filter hostname "$hostname" "$start_time" "$end_time" ;;

esac
