#!/usr/bin/env bash
#iptables rule editor

echo "iptables automated editor" #banner/header

#check user
user=`whoami`
if [ "$user" != "root" ]; then
	echo "Run as root."
	exit -1
fi

#variable declarations
path=/sbin
lastBackup=""

handleDirection(){
	while [ true ]; do
		read -p "(I)nput, (O)utput or (B)oth or (F)orward: " direction
		direction=`echo $direction | tr '[:lower:]' '[:upper:]'`
		if [ "$direction" == "I" -o "$direction" == "INPUT" ]; then
			direction="INPUT"
			break
		elif [ "$direction" == "O" -o "$direction" == "OUTPUT" ]; then
			direction="OUTPUT"
			break
		elif [ "$direction" == "B" -o "$direction" == "BOTH" ]; then
			direction="INPUT OUTPUT"
			break
		elif [ "$direction" == "F" -o "$direction" == "FORWARD" ]; then
			direction="FORWARD"
			break
		else
			echo "Invalid option...try again"
		fi
	done

	echo "$direction" #return value of direction
}

handleProtocol(){
	while [ true ]; do
		read -p "(T)cp, (U)dp or (B)oth: " port
		port=`echo $port | tr '[:lower:]' '[:upper:]'`
		if [ "$port" == "T" -o "$port" == "TCP" ]; then
			port="tcp"
			break
		elif [ "$port" == "U" -o "$port" == "UDP" ]; then
			port="udp"
			break
		elif [ "$port" == "B" -o "$port" == "BOTH" ]; then
			port="tcp udp"
			break
		else
			echo "Invalid option...try again"
		fi
	done

	echo "$port" #return which protocol they want
}

#function to handle denying and allow
handleDenyAllow(){ #needs more testing
	echo
	while [ true ]; do
		echo "1. IP address/range"
		echo "2. Service"
		echo "3. Port number"
		echo "4. All"
		echo "5. Back to main menu"
		read -p "Option: " subOp
		if [ "$subOp" == "1" ]; then #ip address option
			echo "separate multiple options with spaces (eg 1.1.1.1 2.2.2.2 3.3.3.3)"
			read -p "Enter IP address(es) or range(s): " ips
			direction=$(handleDirection) #get the direction/chain
			for ip in $ips; do #loop through all IPs given
				for d in $direction; do #loop through directions in case input and output are both given
					$path/iptables -A $d -s $ip -j $1
				done
			done
			break
		elif [ "$subOp" == "2" ]; then #services option
			echo "separate multiple options with spaces (eg ftp http ssh)"
			read -p "Enter service(s): " services
			direction=$(handleDirection) #get the direction/chain
			for service in $services; do #loop through all IPs given
				for d in $direction; do #loop through directions in case input and output are both given
					protocols=$(handleProtocol)
					for protocol in $protocols; do #loop through all protocols they gave
						$path/iptables -A $d -p $protocol --dport $port -j $1
					done
				done
			done
			break
		elif [ "$subOp" == "3" ]; then #port option
			echo "separate multiple ports w/ spaces (eg 22 80) enter ranges w/ colon (eg 22:80)"
			read -p "Enter port(s): " ports
			direction=$(handleDirection) #get the direction/chain
			for port in $ports; do #loop through all IPs given
				for d in $direction; do #loop through directions in case input and output are both given
					protocols=$(handleProtocol)
					for protocol in $protocols; do #loop through all protocols they gave
						$path/iptables -A $d -p $protocol --dport $port -j $1
					done
				done
			done
			break
		elif [ "$subOp" == "4" ]; then #all traffic option
			direction=$(handleDirection) #get the direction/chain
			for d in $direction; do #loop through directions in case input and output are both given
				$path/iptables -A $d -j $1
			done
			break
		elif [ "$subOp" == "5" ]; then #quitting
			echo "Back to main menu..."
			break
		else
			echo "Invalid option"
		fi
	done #while loop
	echo
}

addTypical(){
	#allow loopback traffic
	$path/iptables -A INPUT -i lo -j ACCEPT
	$path/iptables -A OUTPUT -o lo -j ACCEPT

	#drop bad packets
	$path/iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP #null packets
	$path/iptables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP #syn-flood packets
	$path/iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP #XMAS packets (recon)
	$path/iptables -A INPUT -m state --state INVALID -j DROP #invalid packets
}

allowBasics(){
	#allow ping in/out
	$path/iptables -A INPUT -p icmp --icmp-type 0 -j ACCEPT
	$path/iptables -A OUTPUT -p icmp --icmp-type 0 -j ACCEPT
	$path/iptables -A INPUT -p icmp --icmp-type 8 -j ACCEPT
	$path/iptables -A OUTPUT -p icmp --icmp-type 8 -j ACCEPT

	#allow the good, usual stuff
	$path/iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT #allow established connections
	$path/iptables -A OUTPUT -p tcp -m multiport --dports 80,443 -j ACCEPT #web
	$path/iptables -A INPUT -p udp --sport 53 -j ACCEPT #dns
	$path/iptables -A OUTPUT -p udp --dport 53 -j ACCEPT #dns
}

blockAll(){
	#block everything
	$path/iptables -A INPUT -j DROP
	$path/iptables -A OUTPUT -j DROP
	$path/ip6tables -A INPUT -j DROP
	$path/ip6tables -A OUTPUT -j DROP
}

while [ true ]; do #main while loop
	option=1
	if [ $option -ge 1 -o $option -le 8 ]; then
		echo "1. Drop (services, ports or IPs)"
		echo "2. Accept (services, ports or IPs)"
		echo "3. List all rules"
		echo "4. Flush all rules"
		echo "5. Save/backup"
		echo "6. Restore"
		echo "7. AutoConfig"
		echo "8. Script settings"
		echo "9. Quit"
	fi

	read -p "Option: " option

	if [ "$option" == "1" ]; then #drop option
		handleDenyAllow "DROP"
	elif [ "$option" == "2" ]; then #accept option
		handleDenyAllow "ACCEPT"
	elif [ "$option" == "3" ]; then #list rules
		echo
		echo "All current iptables rules:"
		$path/iptables -L -n
		echo
	elif [ "$option" == "4" ]; then #flush all rules option
		echo
		echo "Flushing all rules..."
		$path/iptables -F
		echo
	elif [ "$option" == "5" ]; then #save/backup options
		read -p "Enter file name to save to: " lastBackup
		$path/iptables-save > $lastBackup
	elif [ "$option" == "6" ]; then #restore option
		read -p "Enter file name to restore to (leave blank to autodetect): " restoreFile
		if [ "$restoreFile" == "" ]; then
			restoreFile="$lastBackup"
			# if [ "$lastBackup" == "" ]; then
			# 	echo "Last backup file not found. Attempting alternate autodetect..."
			#check if this is at the beginning of the file: '# Generated by iptables-save'
			# else
			# 	restoreFile="$lastBackup"
			# fi
		fi
		$path/iptables-restore < $restoreFile
	elif [ "$option" == "7" ]; then #autoconfig option
		while [ true ]; do
			echo "Choose desired configuration (will flush all existing rules first)"
			echo "1. Bare bones security"
			echo "2. Moderate security (recommended)"
			echo "3. High security"
			echo "4. Impenetrable security (everything blocked)"
			echo "5. Back to main menu"

			read -p "Enter option: " answer
			echo
			echo "Applying settings..."
			$path/iptables -F
			if [ "$answer" == "1" ]; then
				#logs
				$path/iptables -A INPUT -m limit --limit 5/min -j LOG --log-level 4 --log-prefix 'In5/m '
				$path/iptables -A INPUT -m state --state INVALID -j LOG --log-level 4 --log-prefix 'InvalidDrop '
				$path/iptables -A OUTPUT -m limit --limit 15/hour -j LOG --log-level 4 --log-prefix 'OutAllow15/h '

				addTypical #add typical rules
				break
			elif [ "$answer" == "2" ]; then
				#logs
				$path/iptables -A INPUT -j LOG --log-level 4 --log-prefix 'InDrop '
				$path/iptables -A INPUT -m state --state INVALID -j LOG --log-level 4 --log-prefix 'InvalidDrop '
				$path/iptables -A OUTPUT -j LOG --log-level 4 --log-prefix 'OutAllow '

				addTypical #add typical rules
				allowBasics #add basic usage rules
				#add other basic usage rules
				$path/iptables -A INPUT -p udp -m multiport --sports 67,68 -j ACCEPT #dhcp
				$path/iptables -A OUTPUT -p udp -m multiport --dports 67,68 -j ACCEPT #dhcp
				$path/iptables -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT #ssh
				$path/iptables -A OUTPUT -p tcp -m tcp --dport 22 -j ACCEPT #ssh
				$path/iptables -A INPUT -p tcp --sport 21 -m state --state ESTABLISHED -j ACCEPT #ftp connection
				$path/iptables -A OUTPUT -p tcp --dport 21 -m state --state NEW,ESTABLISHED -j ACCEPT #ftp connection
				$path/iptables -A INPUT -p tcp --sport 20 -m state --state ESTABLISHED,RELATED -j ACCEPT #active ftp
				$path/iptables -A OUTPUT -p tcp --dport 20 -m state --state ESTABLISHED -j ACCEPT #active ftp
				$path/iptables -A INPUT -p tcp --sport 1024: --dport 1024: -m state --state ESTABLISHED,RELATED -j ACCEPT #passive ftp
				$path/iptables -A OUTPUT -p tcp --sport 1024: --dport 1024:  -m state --state ESTABLISHED,RELATED -j ACCEPT #passive ftp

				#handle the rest
				$path/iptables -A INPUT -j DROP #block all incoming
				$path/iptables -A OUTPUT -j ACCEPT #accept all outgoing
				break
			elif [ "$answer" == "3" ]; then
				#logs
				$path/iptables -A INPUT -j LOG --log-level 5 --log-prefix 'InDrop '
				$path/iptables -A INPUT -m state --state INVALID -j LOG --log-level 5 --log-prefix 'InvalidDrop '
				$path/iptables -A OUTPUT -j LOG --log-level 5 --log-prefix 'OutAllow '

				addTypical #add typical rules
				allowBasics #add basic usage rules
				blockAll #block all the rest. ipv4 and v6
				break
			elif [ "$answer" == "4" ]; then
				#log everything
				$path/iptables -A INPUT -j LOG --log-level 7 --log-prefix "INv4 "
				$path/iptables -A OUTPUT -j LOG --log-level 7 --log-prefix "OUTv4 "
				$path/ip6tables -A INPUT -j LOG --log-level 7 --log-prefix "INv6 "
				$path/ip6tables -A OUTPUT -j LOG --log-level 7 --log-prefix "OUTv6 "

				blockAll #block all the rest. ipv4 and v6
				break
			elif [ "$answer" == "5" ]; then
				echo "Back to main menu..."
				break
			else
				echo "Invalid option...try again"
			fi

		done
	elif [ "$option" == "8" ]; then #script settings option
		while [ true ]; do
			echo "1. List current script settings"
			echo "2. Change a setting value"
			echo "3. Back to main menu"

			read -p "Enter option: " answer
			if [ "$answer" == "1" ]; then
				echo
				echo "Settings: "
				echo "Path to iptables: $path"
				echo "other stuff possibly"
			elif [ "$answer" == "2" ]; then
				echo "change settings"
			elif [ "$answer" == "3" ]; then
				echo "Back to main menu..."
				break
			else
				echo "Invalid option...try again"
			fi

		done
	elif [ "$option" == "9" ]; then #quit
		exit 0
	else #wrong number
		echo "Invalid option...try again"
	fi

done #end big while loop
