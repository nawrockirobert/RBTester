#!/bin/bash
MY_PATH=$1
message="Tester le RB3011 ? Appuyez sur (Entrer) pour continuer ou E pour quitter"
#declaration de variables
Ipvl=192.168.88.1
nbping=20
ping_max="20"
tempcomptearebour=200
PORTS=(ether1 ether2 ether3 ether4 ether5 ether6 ether7 ether8 ether9 ether10 sfp1)
rtest=0
Resultaping=1
#Recuperation du non du scripte lancé sans l'extention
Filename=${0##*/}
Filename=${Filename%.*}
#Creation du dossier ou poser les logs en creant les parent s'ils n'existent pas sans message d'erreur sil existent
mkdir -p ${MY_PATH}/Resulta/${Filename}
log=${MY_PATH}/Resulta/${Filename}/$(date +%F).log
#num de serie mac port1 plus resultat mis dans un fishier ensuite reset du MK
function Loging {
	SN=$(ssh admin@${Ipvl} ":put [/system routerboard get serial-number]")
	MAC=$(ssh admin@${Ipvl} ":put [/interface ethernet get ether1 mac-address ]")
	if [ ${rtest} == 1 ] ; then
		if [ ${Resultatest} == 0 ] || [ ${Resultaping} == 0 ] ; then
			diag="FAIL"
		else
			diag="SUCCESS"
		fi
	else
	diag="SUCCESS"
	fi
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
#compte à rebour de la duree entree tout en haut
function comptearebour {
	echo "debut du test sur ${Ipvl} dans" $tempcomptearebour "secondes"
		for (( i = $tempcomptearebour; i >= 0; i-- )) ; do
			sleep 1
			if (( ${i} == 60 )) || (( ${i} == 120 )) || (( ${i} <= 10 )) || (( ${i} == 180 )) ; then
				echo ${i} secondes restantes
			fi
		done
}
function Tester {
	countTest=$((countTest+1))
	Resultatest="1"
	portsfailed=""
	UDPort=""
	if [ ${rtest} == 0 ] ; then
		read -p $'\n\033[32;3m'"Branchez que le PORT SFP au RB960 et le PORT 10 a la borne NS5AC du testeur (cable à l'etiquette NS) ensuite appuyer sur entrer"$'\n\033[0m' pff
		ssh-keygen -f "/home/$USER/.ssh/known_hosts" -R "${Ipvl}"
		read -p $'\n\033[32;3m'"Branchez les reste des ports au switch cisco noir nommé CICI et appuyez sur entrer"$'\n\033[0m' pff
		echo -e '\n\033[32;3m'"veuillez patienter quelques instants\033[0m"
		ssh admin@${Ipvl} "exit"
		echo "___________________________________________"
		echo ""
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
			Resultatest=0
		fi
		if [[ "${RATE}" == *Gbps* ]] && [[ "${DUPLEX}" == *yes* ]] && [ -z "${outputPort}" ] && [ -z "${outputmega}" ] && [ -z "${outputduplex}" ] ; then
			echo "reussis"
		else
			Resultatest=0
			UDPort=${UDPort}" "${PORT}
		fi
		echo -e "--\n"
	done
	#appelle la fonction de ping
	ppping
	if [ ${Resultatest} == 0 ] || [ ${Resultaping} == 0 ] ; then
		echo "test raté"
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
		if [ ${rtest} == 0 ] ; then
			rtest=1
			echo "nouvelle tentative de test dans .."
			for i in {3..1..-1} ; do
				sleep 1
				echo ${i}
			done
			Tester
		fi
	else
		echo "test reussit"
		echo ""
		#reset le MK en etat dusine et lance un script de music pour la reussite de test depuis le Rb960 de prod
		sshpass -p 'admin' ssh admin@192.168.88.3 "/system script run 0"
		echo "Vous pouvez débrancher tout les ports ethernet et laisser l'allimentation le temps que le RB3011 redemarre"
		echo ""
		echo ""
		message="Passez au RB3011 suivant ? Appuyez sur (Entrer) pour continuer ou E pour quitter"	
	fi
}
#impression des donnés si la valeur n'est pas vide
function print_not_empty {
	if [ -n "${2}" ] ; then
		echo "${1}: ${2}"
	fi
}

while true ; do
	read -p "${message}"$'\n>' userchoice
	case $userchoice in
		[Ee] ) exit;;
		* ) rtest=0;countTest=0;Tester;Loging;;
	esac
done
