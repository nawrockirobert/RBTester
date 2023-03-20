#!/bin/bash
mkdir -p ./Resulta/Logs/$(date +%F)
MY_PATH="$(dirname -- "${BASH_SOURCE[0]}")"            # relative
MY_PATH="$(cd -- "$MY_PATH" && pwd)"    # absolutized and normalized
if [[ -z "$MY_PATH" ]] ; then
  # error; for some reason, the path is not accessible
  # to the script (e.g. permissions re-evaled after suid)
  exit 1  # fail
fi
while true ; do
	read -p "(1) RB750 (2) RB3011 (3) RB960(incomplet)" userchoice
	case $userchoice in
		1 ) Fname=RB750;logz=./Resulta/Logs/$(date +%F)/${Fname}.log; ~/Documents/.Testeurs/RB750.sh "$MY_PATH" | tee -a $logz;;
		2 ) Fname=RB3011;logz=./Resulta/Logs/$(date +%F)/${Fname}.log;~/Documents/.Testeurs/RB3011.sh "$MY_PATH" | tee -a $logz;;
		3 ) Fname=RB960;logz=./Resulta/Logs/$(date +%F)/${Fname}.log;~/Documents/.Testeurs/RB960.sh "$MY_PATH" | tee -a $logz;;
		* ) echo "mauvais choix";;
	esac
done
