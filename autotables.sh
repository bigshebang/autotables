#!/usr/bin/env bash
#iptables rule editor

echo "iptables automated editor (run as root)"

path=/sbin
lastBackup=""

handleDirection(){
	while [ true ]; do
		read -p "(I)nput, (O)utput or (B)oth or (F)orward: " direction
		direction=`echo $direction | tr '[:lower:]' '[:upper:]'`
		if [ "$direction" == "I" -o "$direction" == "INPUT" ]; then
			$direction="INPUT"
			break
		elif [ "$direction" == "O" -o "$direction" == "OUTPUT" ]; then
			$direction="OUTPUT"
			break
		elif [ "$direction" == "B" -o "$direction" == "BOTH" ]; then
			$direction="INPUT OUTPUT"
			break
		elif [ "$direction" == "F" -o "$direction" == "FORWARD" ]; then
			$direction="FORWARD"
			break
		else
			echo "Invalid option...try again"
		fi
	done

	echo "$direction" #return value of direction
}

#function to handle denying and allow
handleDenyAllow(){
	subOp=""
	while [ true ]; do
		echo "1. IP address/range"
		echo "2. Service"
		echo "3. Port number"
		echo "4. All"
		echo "5. Back to main menu"
		read -p "Option: " subOp
		echo "separate multiple options with spaces (eg 22 80 443)"
		if [ "$subOp" == "1" ]; then
			read -p "Enter IP address(es) or range(s): " answer
			break
		elif [ "$subOp" == "2" ]; then
			read -p "Enter service(s): " answer
			break
		elif [ "$subOp" == "3" ]; then
			read -p "Enter port(s): " answer
			break
		elif [ "$subOp" == "4" ]; then
			echo "hey you picked All"
			break
		elif [ "$subOp" == "5" ]; then
			echo "back to main menu..."
			break
		else
			echo "Invalid option"
		fi
	done
	
	if [ $subOp -lt 4 ]; then
		direction=$(handleDirection) #get the direction/chain
	fi
}

while [ true ]; do
	option=1
	if [ $option -ge 1 -o $option -le 8 ]; then
		echo "1. List all rules"
		echo "2. Deny (services, ports or IPs)"
		echo "3. Allow (services, ports or IPs)"
		echo "4. Save"
		echo "5. Restore"
		echo "6. AutoConfig"
		echo "7. Flush all rules"
		echo "8. Script settings"
		echo "9. Quit"
	fi

	read -p "Option: " option

	if [ "$option" == "1" ]; then
		echo
		echo "All current iptables rules:"
		$path/iptables -L
		echo
	elif [ "$option" == "2" ]; then
		handleDenyAllow
	elif [ "$option" == "3" ]; then
		handleDenyAllow
	elif [ "$option" == "4" ]; then
		read -p "Enter file name to save to: " lastBackup
		$path/iptables-save > $lastBackup
	elif [ "$option" == "5" ]; then
		read -p "Enter file name to restore to (leave blank to use last saved file): " restoreFile
		if [ "$restoreFile" == "" ]; then
			$restoreFile="$lastBackup"
		fi
		$path/iptables-restore < $restoreFile
	elif [ "$option" == "6" ]; then
		echo "autoConfig option"
	elif [ "$option" == "7" ]; then
		echo
		echo "Flushing all rules..."
		$path/iptables -F
		echo
	elif [ "$option" == "8" ]; then
		echo "script settings option...not functional yet"
	elif [ "$option" == "9" ]; then
		exit 0
	else
		echo "you dun goofed"
	fi

done #end big while loop

