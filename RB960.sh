MY_PATH=$1
message="Tester le RB960 ? Appuyez sur (Entrer) pour continuer ou E pour quitter"
#declaration de variables
Ipvl=192.168.88.1
nbping=20
ping_max="20"
tempcomptearebour=200
PORTS=(ether1 ether2 ether3 ether4 ether5 sfp1)
rtest=0
#Recuperation du non du scripte lancé sans l'extention
Filename=${0##*/}
Filename=${Filename%.*}
#Creation du dossier ou poser les logs en creant les parents s'ils n'existent pas sans message d'erreur sil existent
mkdir -p ${MY_PATH}/Resulta/${Filename}
log=${MY_PATH}/Resulta/${Filename}/$(date +%F).log
#num de serie mac port1 plus resultat mis dans un fishier ensuite reset du MK
function Loging {
	SN=$(ssh admin@${Ipvl} ":put [/system routerboard get serial-number]")
	MAC=$(ssh admin@${Ipvl} ":put [/interface ethernet get ether1 mac-address ]")
	if [ ${rtestv} == 1 ] || [ ${rtestV} == 1 ] ; then
		if [ ${Resultatestv} == 0 ] || [ ${ResultatestV} == 0 ] || [ ${Resultaping} == 0 ] ; then
			diag="FAIL"
			echo "le RB960 est Hs"
		else
			diag="SUCCESS"
			echo "le RB960 est Ok"
		fi
	else
	diag="SUCCESS"
	echo "le RB960 est Ok"
	fi
	echo $SN $MAC $diag $average_speed $UDPort $portsfailed 
	echo "Vous pouvez débrancher tout les ports ethernet et laisser l'allimentation le temps que le RB960 redemarre"
	echo ""
	echo ""
	message="Passez au RB960 suivant ? Appuyez sur (Entrer) pour continuer ou E pour quitter"
	echo $SN $MAC $diag $average_speed $UDPort $portsfailed | sed 's/\r//g' >> $log
	sshpass -p 'admin' ssh admin@${Ipvl} "/system reset-configuration"
}
#ping a travers RB960 de prod
function ppping {
	echo "debut du test de ping sur ${nbping} repetitions" 
	Resultaping=1
	output=$(sshpass -p 'admin' ssh admin@192.168.88.3 "ping ${Ipvl} count=${nbping}")
	average_speed=$(echo "$output" | grep 'avg-rtt' | awk '{ print $5 }')
	#retire les chars
	average_speedint="${average_speed//[!0-9]/}"
	#retire les int
	average_speedchar="${average_speed//[[:digit:]]/}"
	echo "${average_speed}"
	echo "RTT moyen sur ${nbping} ping :${average_speedint}"
	if [[ "${average_speedchar}" == *ms* ]] ; then
		if (( $( echo "$average_speedint > $ping_max" | bc -l) )) ; then
			Resultaping=0
			echo "ping NOK"
		else
			echo "ping OK"
		fi
	else
	Resultaping=0
	fi
}
function conf {
for PORT in "${PORTS[@]}" ; do
	sshpass -p 'admin' ssh admin@${Ipvl} "/interface ethernet set loop-protect=off ${PORT}"
done
}
#compte à rebour de la duree entree tout en haut
function comptearebour {
	echo "debut du test sur ${Ipvl} dans" $tempcomptearebour "secondes"
		for (( i = $tempcomptearebour; i >= 0; i-- )) ; do
			sleep 1
			if (( ${i} == 60 )) || (( ${i} == 120 )) || (( ${i} <= 10 )) || (( ${i} == 180 )) ; then
				if (( ${i} >= 10 )) ; then
					echo ${i} secondes restantes
				else
					echo ${i}
				fi
			fi
		done
}
function Tester24 {
	countTest=$((countTest+1))
	Resultatestv="1"
	Resultaping="1"
	portsfailed=""
	UDPort=""
	voltest="23"
	if [ ${rtestv} == 0 ] ; then
		read -p $'\n\033[32;3m'"Branchez le module SPF au RB960, l'alimentation ensuite et appuyer sur entrer"$'\n' pff
		echo -e "\nAttente de 30 secondes pour que le RB960 s'allume\n\033[0m"
		sleep 30
		ssh-keygen -f "/home/$USER/.ssh/known_hosts" -R "${Ipvl}"
		echo -e '\n\033[32;3m'"veuillez patienter quelques instants\033[0m"
		ssh admin@${Ipvl} "/ip dhcp-server disable 0"
		conf
		read -p $'\n\n'"Branchez les cables à l'etiquette"$'\033[31;1m'" NS sur les ports de 2 a 5 du RB960 à Tester "$'\033[0m'"et brancher le cable etiqueté "$'\033[31;1m'"KO au port 1 "$'\033[0m'"ensuite le appuyer sur entrer"$'\n\n' pff
		echo "___________________________________________"
		echo -e "\n\n\n"
		comptearebour
		SN=$(ssh admin@${Ipvl} ":put [/system routerboard get serial-number]")
		echo "numero de serie : "$SN
	fi
	echo -e "--\n"
	#test en lui meme
	for PORT in "${PORTS[@]}" ; do
		outputPort=""
		outputmega=""
		outputduplex=""
		VOLTAGE=$(ssh admin@${Ipvl} "/interface ethernet poe monitor ${PORT} once" | grep 'poe-out-voltage' | awk '{print $2}')
		RATE=$(ssh admin@${Ipvl} "/interface ethernet monitor ${PORT} once" | grep 'rate' | awk '{print $2}')
		DUPLEX=$(ssh admin@${Ipvl} "/interface ethernet monitor ${PORT} once" | grep 'full-duplex' | awk '{print $2}')
		MAC=$(ssh admin@${Ipvl} ":put [/interface ethernet get ${PORT} mac-address ]")
		outputPort=$(ssh admin@${Ipvl} "/log print where time>([/system clock get time] - 2m)" | grep down | grep ${PORT})
		outputmega=$(ssh admin@${Ipvl} "/log print where time>([/system clock get time] - 2m)" | grep 0M | grep ${PORT})
		outputduplex=$(ssh admin@${Ipvl} "/log print where time>([/system clock get time] - 2m)" | grep half | grep ${PORT})

		print_not_empty "PORT" "${PORT}"
		print_not_empty "MAC" "${MAC}"
		print_not_empty "RATE" "${RATE}"
		print_not_empty "DUPLEX" "${DUPLEX}"
		print_not_empty "VOLTAGE" "${VOLTAGE}"
		#retire les charactére alphabetiques pour comparer les integers
		RATE=${RATE//[[:digit:]]/}
		#passe la var resulta a 0 si un test est raté
		if [ -n "${outputPort}" ] || [ -n "${outputmega}" ] || [ -n "${outputduplex}" ] ; then
			TTIME=$(ssh admin@${Ipvl} ":put [/system clock get time]")
			echo "le port "${PORT} " a bagoté"
			print_not_empty "System TIME" "${TTIME}"
			echo "Log de l'erreur:"
			echo "${outputPort}"
			echo "${outputmega}"
			portsfailed=${portsfailed}" "${PORT}
			Resultatestv=0
		fi
#		if [[ ${PORT} != *ether1* ]] || [[ ${PORT} != *sfp1* ]] ; then
			if [[ "${RATE}" == *Gbps* ]] && [[ "${DUPLEX}" == *yes* ]] && [ -z "${outputPort}" ] && [ -z "${outputmega}" ] && [ -z "${outputduplex}" ] && (( $(echo "$VOLTAGE $voltest" | awk '{print ($1 > $2)}') )) ; then
				echo "reussis"
			else
				Resultatestv=0
				UDPort=${UDPort}" "${PORT}
			fi
#		fi
		echo -e "--\n"
	done
	#appelle la fonction de ping
	ppping
	if [ ${Resultatestv} == 0 ] || [ ${Resultaping} == 0 ] ; then
		echo -e '\033[31;1m'"test raté sur 24V"'\033[0m'
		#notif sonore d'echec depuis RB960 de prod long beep de 3 secondes
		sshpass -p 'admin' ssh admin@192.168.88.3 "beep length=2s"
		#print quelles port on bagoté
		if [ -n "${portsfailed}" ] ; then
			echo "sur les port"${portsfailed}
		fi
		#print quel ports sont actuellement down
		if [ -n "${UDPort}" ] ; then
			echo "Le(s) ports ""${UDPort}"" sont down"
		fi
		#si le test est raté et le teste nas pas deja ete refait une fois refait le test
		if [ ${rtestv} == 0 ] ; then
			rtestv=1
			echo "nouvelle tentative de test dans .."
			for i in {3..1..-1} ; do
				sleep 1
				echo ${i}
			done
			Tester24
		fi
	else
		echo "test reussit sur 24V"
		echo ""
		# lance un script de music pour la reussite de test depuis le Rb960 de prod
		sshpass -p 'admin' ssh admin@192.168.88.3 "/system script run 0"
		echo -e "\n\n"
	fi
}
function Tester48 {
	countTest=$((countTest+1))
	ResultatestV="1"
	Resultaping="1"
	portsfailed=""
	UDPort=""
	voltest="47"
	if [ $rtestV == 0 ] ; then
		read -p $'033[32;3m'"Debranchez l'alimentation 24V et branchez la 48V à la place et appuyer sur entrer"$'\n\033[0m' pff
	fi
		sleep 1
		echo "___________________________________________"
		sleep 1
		echo ""
		comptearebour
	echo -e "--\n"
	#test en lui meme
	for PORT in "${PORTS[@]}" ; do
		outputPort=""
		outputmega=""
		outputduplex=""
		VOLTAGE=$(ssh admin@${Ipvl} "/interface ethernet poe monitor ${PORT} once" | grep 'poe-out-voltage' | awk '{print $2}')
		RATE=$(ssh admin@${Ipvl} "/interface ethernet monitor ${PORT} once" | grep 'rate' | awk '{print $2}')
		DUPLEX=$(ssh admin@${Ipvl} "/interface ethernet monitor ${PORT} once" | grep 'full-duplex' | awk '{print $2}')
		MAC=$(ssh admin@${Ipvl} ":put [/interface ethernet get ${PORT} mac-address ]")
		outputPort=$(ssh admin@${Ipvl} "/log print where time>([/system clock get time] - 2m)" | grep down | grep ${PORT})
		outputmega=$(ssh admin@${Ipvl} "/log print where time>([/system clock get time] - 2m)" | grep 0M | grep ${PORT})
		outputduplex=$(ssh admin@${Ipvl} "/log print where time>([/system clock get time] - 2m)" | grep half | grep ${PORT})

		print_not_empty "PORT" "${PORT}"
		print_not_empty "MAC" "${MAC}"
		print_not_empty "RATE" "${RATE}"
		print_not_empty "DUPLEX" "${DUPLEX}"
		print_not_empty "VOLTAGE" "${VOLTAGE}"
		#retire les charactére alphabetiques pour comparer les integers
		RATE=${RATE//[[:digit:]]/}
		#passe la var resulta a 0 si un test est raté
		if [ -n "${outputPort}" ] || [ -n "${outputmega}" ] || [ -n "${outputduplex}" ] ; then
			TTIME=$(ssh admin@${Ipvl} ":put [/system clock get time]")
			echo "le port "${PORT} " a bagoté"
			print_not_empty "System TIME" "${TTIME}"
			echo "Log de l'erreur:"
			echo "${outputPort}"
			echo "${outputmega}"
			portsfailed=${portsfailed}" "${PORT}
			ResultatestV=0
		fi
#		if [[ ${PORT} != "ether1" ]] || [[ ${PORT} != "sfp1" ]] ; then
			if [[ "${RATE}" == *Gbps* ]] && [[ "${DUPLEX}" == *yes* ]] && [ -z "${outputPort}" ] && [ -z "${outputmega}" ] && [ -z "${outputduplex}" ] && (( $(echo "$VOLTAGE $voltest" | awk '{print ($1 > $2)}') )) ; then
				echo "reussis"
			else
				ResultatestV=0
				UDPort=${UDPort}" "${PORT}
			fi
#		fi
		echo -e "--\n"
	done
	#appelle la fonction de ping
	ppping
	if [ ${ResultatestV} == 0 ] || [ ${Resultaping} == 0 ] ; then
		echo -e '\033[31;1m'"test raté sur 48V"'\033[0m'
		#notif sonore d'echec depuis RB960 de prod long beep de 3 secondes
		sshpass -p 'admin' ssh admin@192.168.88.3 "beep length=2s"
		#print quelles port on bagoté
		if [ -n "${portsfailed}" ] ; then
			echo "sur les port"${portsfailed}
		fi
		#print quel ports sont actuellement down
		if [ -n "${UDPort}" ] ; then
			echo "Le(s) ports ""${UDPort}"" sont down"
		fi
		#si le test est raté et le teste nas pas deja ete refait une fois refait le test
		if [ ${rtestV} == 0 ] && [ ${ResultatestV} == 0 ] ; then
			rtestV=1
			echo "nouvelle tentative de test dans .."
			for i in {3..1..-1} ; do
				sleep 1
				echo ${i}
			done
			Tester48
		fi
	else
		echo -e '\033[32m'"test reussit sur 48V"'\033[0m'
		echo ""
		#reset le MK en etat dusine et lance un script de music pour la reussite de test depuis le Rb960 de prod
		sshpass -p 'admin' ssh admin@192.168.88.3 "/system script run 0"
		echo ""
		echo ""	
	fi
}
#impression des donnés si la valeur n'est pas vide
function print_not_empty {
	if [ -n "${2}" ] ; then
		echo "${1}: ${2}"
	fi
}

while true ; do
	read -p "${message}"$'\n' userchoice
	case $userchoice in
		[Ee] ) exit;;
		* ) rtestv=0;rtestV=0;countTest=0;Tester24;Tester48;Loging;;
	esac
done
