#!/bin/bash
shopt -s extglob
IPTABLES_VAR(){
	Protocol=
	MyChain=
	MyInterface=
	IpVersion="iptables ip6tables"
	IptableStat=
	SourceNet=
	SPortRange=
	DesNet=
	DPortRange=
}
#iptables�Ļ������úͱ���
IPTABLES_BASE_SET(){
	INSTALL_BASE_PACKAGES iptables
	[ ! -d $ScriptPath/backup ] && mkdir $ScriptPath/backup
	for var in iptables ip6tables ; do
		$var-save > $ScriptPath/backup/$var.up.rules.backup$(date +"%Y%m%d")
		$var -F
		$var -t nat -F
		$var -X
		$var -P INPUT DROP
		$var -P OUTPUT ACCEPT
		$var -P FORWARD ACCEPT
		$var -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s --limit-burst 10 -j ACCEPT
		$var -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
		$var -A INPUT -i lo -j ACCEPT
		$var -A OUTPUT -o lo -j ACCEPT
		$var -A INPUT -p tcp --dport ssh -j ACCEPT
	done
}
INTERFACE_CHOOSE(){
	Interfaces=`ifconfig|awk '!/^ |^$|lo/ {print $1}'`
	if [ -z "$Interfaces" ] ; then
		echo "No effective ethernet , please setup the ethernet ."
		exit 1
	fi
	select var in $Interfaces "lo" "all"; do
		case $var in
			$var)
				[ "$var" == "all" ] && MyInterface="" || MyInterface="-i $var"
				break;;
		esac
	done
}
IPTABLES_CHAINS_CHOOSE(){
	MyChains="INPUT OUTPUT FORWARD PREROUTING POSTROUTING"
	INPUT_CHOOSE $MyChains
	[ -n $VarTmp ] && MyChain=$VarTmp || IPTABLES_CHAINS_CHOOSE
}
IPTABLES_PROTOCOL_SET(){
	Protocols="icmp tcp udp ah udplite sctp dccp"
	INPUT_CHOOSE $Protocols
	[ -n "$VarTmp" ] && Protocol="-p $VarTmp" || Protocol=""
}
#������Ҫ��Ч�Ķ˿ں�
IPTABLES_SET_PORT(){
	InputPorts=""
	InputPort=""
	while true ;do
		read -p "For every input port and then press enter to enter another, input 'r' or 'R' reset input, input 'a' of 'A' choose all port, input 'n' of 'N' exit : " InputPort
		case $InputPort in
			[1-9][0-9]*)
				if [ $InputPort -ge 65535 ];then
					echo "the port number is illegal, please input again."
				else
					tmp=$InputPorts
					[ -z "$InputPorts" ] && InputPorts=$InputPort || InputPorts=$InputPort,$tmp
				fi
				;;
			a|A)
				InputPorts=""
				break;;
			n|N)
				break;;
			r|R)
				InputPorts="";;
			*)
				echo "input is not number, please input again";;
		esac
		echo "your port number is $InputPorts"
	done
	#[ -z $InputPorts ] && echo "nothing to do" || IPTABLES_INPUT_SET $InputPorts
	read -p "$InputPorts is setup in iptables" -t 5 ok
}
IPTABLES_SET_IP(){
	InputIp=""
	ext4ip="[0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5]"
	while true ;do
		read -p "Please input a valid IP and then press enter, input err ip to reset input, input 'n' of 'N' exit : " InputIp
		case $InputIp in
			@($ext4ip).@($ext4ip).@($ext4ip).@($ext4ip))
				IpVersion="iptables"
				break;;
			@($ext4ip).@($ext4ip).@($ext4ip).@($ext4ip)-@($ext4ip))
				IpVersion="iptables"
				break;;
			@($ext4ip).@($ext4ip).@($ext4ip).@($ext4ip)/@([1-9]|[12][0-9]|3[0-2]))
				IpVersion="iptables"
				break;;
			n|N)
				InputIp=""
				break;;
			*)
				echo "input is not valid ip, please input again";;
		esac
	done
}
IPTABLES_STATUS_SET(){
	IpStatus="ACCEPT DROP"
	INPUT_CHOOSE $IpStatus
	[ -n $VarTmp ] && IptableStat="-j $VarTmp" || IPTABLES_STATUS_SET
}
#���ӷ���ǽ�Ĺ���
IPTABLES_INPUT_SET(){
	IPTABLES_VAR
	echo "#############################################"
	echo "#which interface are you choose?"
	echo "#############################################"
	INTERFACE_CHOOSE
	echo "#############################################"
	echo "#which chains are you choose?"
	echo "#############################################"
	IPTABLES_CHAINS_CHOOSE
	echo "#############################################"
	echo "#which protocol are you choose?"
	echo "#############################################"
	IPTABLES_PROTOCOL_SET
	echo "#############################################"
	echo "#which source ip are you choose?"
	echo "#############################################"
	IPTABLES_SET_IP
	[ -n "$InputIp" ] && SourceNet="-s $InputIp" || SourceNet=""
	echo "#############################################"
	echo "#which source port are you choose?"
	echo "#############################################"
	IPTABLES_SET_PORT
	[ -n "$InputPorts" ] && SPortRange="--sport $InputPorts" || SPortRange=""
	echo "#############################################"
	echo "#which destination ip are you choose?"
	echo "#############################################"
	IPTABLES_SET_IP
	[ -n "$InputIp" ] && DesNet="$InputIp" || DesNet=""
	echo "#############################################"
	echo "#which destination port are you choose?"
	echo "#############################################"
	IPTABLES_SET_PORT
	[ -n "$InputPorts" ] &&	DPortRange="--dport $InputPorts" || DPortRange=""
	echo "#############################################"
	echo "#which status are you choose?"
	echo "#############################################"
	IPTABLES_STATUS_SET
	for var in $IpVersion ; do
		if [ "$(echo $SPortRange|grep ',')" -o "$(echo $DPortRange|grep ',')" ] ; then
			ModuleName="-m multiport"
			until [ "$Protocol" == "-p tcp" -o "$Protocol" == "-p udp" -o "$Protocol" == "-p udplite" -o "$Protocol" == "-p sctp" -o "$Protocol" == "-p dccp" ] ; do
					echo "#############################################"
					echo "#You must choose the protocol with '-p tcp, -p udp, -p udplite, -p sctp or -p dccp'!"
					echo "#############################################"
					IPTABLES_PROTOCOL_SET
			done
		else
			ModuleName=""
		fi
		read -p "$var $1 $MyChain $Protocol $MyInterface $ModuleName $SourceNet $SPortRange $DesNet $DPortRange $IptableStat" -t 5 ok
		$var $1 $MyChain $Protocol $MyInterface $ModuleName $SourceNet $SPortRange $DesNet $DPortRange $IptableStat
	done
}
SELECT_IPTABLES_FUNCTION(){
	clear;
	echo "[Notice]How to set up iptables:"
	select var in "Check iptables rules and status" "Setup iptables" "Add rules" "Del rules" "back";do
		case $var in
			"Check iptables rules and status")
				iptables -L -n -v
				ip6tables -L -n -v
				PASS_ENTER_TO_EXIT;;
			"Setup iptables")
				IPTABLES_BASE_SET;;
			"Add rules")
				IPTABLES_INPUT_SET "-A";;
			"Del rules")
				IPTABLES_INPUT_SET "-D";;			
			"back")
				SELECT_RUN_SCRIPT;;
		esac
	done
}
