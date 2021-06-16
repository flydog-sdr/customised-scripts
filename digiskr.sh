#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

VER="1.0"

# Define font colour
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Green_background_prefix="\033[42;37m"
Red_background_prefix="\033[41;37m"
Font_color_suffix="\033[0m"

# Define log colour
INFO="${Green_font_prefix}[INFO]${Font_color_suffix}"
ERROR="${Red_font_prefix}[ERROR]${Font_color_suffix}"
TIP="${Green_font_prefix}[TIP]${Font_color_suffix}"

# Generating configuration from template
configure_digiskr() {
    mkdir -p /etc/digiskr
	echo
	read -p " [1] Please enter the user password of FlyDog SDR (press Enter for none): " PASSWORD
	read -p " [2] Please enter the time limit exemption password of FlyDog SDR (press Enter for none): " TLIMIT_PASSWORD
	while [[ "x${CALLSIGN}" == "x" ]] 
    do
        read -p " [3] Your callsign is: " CALLSIGN
    done
	sleep 5s
	echo
    echo -e "${INFO} Next, you need to fill in the bands to be decoded."
	echo -e "${TIP} Available bands are: 160m, 80m, 60m, 40m, 30m, 20m, 17m, 15m, 12m, 10m."
	echo -e "${TIP} Example given: 10, 15, 17, 20, 30, 40"
	sleep 5s
	case "${USERS_MAX}" in
		3)
		echo -e "${INFO} It seems that your FlyDog SDR have ${Red_font_prefix}[3]${Font_color_suffix} channels."
		echo -e "${TIP} You can fill in up to ${Red_font_prefix}[3]${Font_color_suffix} bands, otherwise it will cause software error."
		echo
		read -p " [4] Please input the bands you want to decode, separate by commas: " BANDS
		;;
		4)
		echo -e "${INFO} It seems that your FlyDog SDR have ${Red_font_prefix}[4]${Font_color_suffix} channels."
		echo -e "${TIP} You can fill in up to ${Red_font_prefix}[4]${Font_color_suffix} bands, otherwise it will cause software error."
		echo
		read -p " [4] Please input the bands you want to decode, separate by commas: " BANDS
		;;
		8)
		echo -e "${INFO} It seems that your FlyDog SDR have ${Red_font_prefix}[8]${Font_color_suffix} channels."
		echo -e "${TIP} You can fill in up to ${Red_font_prefix}[8]${Font_color_suffix} bands, otherwise it will cause software error."
		echo
		read -p " [4] Please input the bands you want to decode, separate by commas: " BANDS
		;;
		14)
		echo -e "${INFO} It seems that your FlyDog SDR have ${Red_font_prefix}[14]${Font_color_suffix} channels."
		echo -e "${TIP} However, only 10 bands are within the coverage frequency..."
		echo
		read -p " [4] Please input the bands you want to decode, separate by commas: " BANDS
		;;
	esac
cat << EOF > /etc/digiskr/settings.py
# DO NOT EDIT THE CONFIG MANUALLY!
TMP_PATH = '/tmp/digiskr'
LOG_PATH = '/var/log/digiskr'
LOG_TO_FILE = False
LOG_BACKUP_COUNT = 0
LOG_SPOTS = False
WSJTX = {'decoding_depth_global':3,'decoding_depth_modes':{'FT8':3}}
DECODER_QUEUE = {'maxsize':10,'workers':2}
STATIONS = {'flydog-sdr':{'server_host':'flydog-sdr','server_port':8073,'password':'${PASSWORD}','tlimit_password':'${TLIMIT_PASSWORD}','callsign':'${CALLSIGN}'}}
SCHEDULES = {'*':{'flydog-sdr':[${BANDS}]}}
EOF
    sleep 5s
	echo && echo -e "${INFO} Congratulations! The configuration is ready..."
}

# Start, Stop and Restart actions
control_digiskr() {
	echo
	docker ${1} digiskr &>/dev/null
	echo -e "${INFO} Done, returning to the menu..."
	sleep 5s
	start_menu
}

# Install Digiskimmer
install_digiskr() {
	echo
	if [[ "DIGISKR_IMAGE" == "true" ]] && [[ "DIGISKR_DEPLOYED" == "true" ]] && [[ "DIGISKR_RUNNING" == "true" ]]; then
		echo -e "${INFO} Digiskimmer is installed and running, returning to the menu..."
		echo -e "${TIP} If you want to upgrade Digiskimmer, please uninstall and install again."
		sleep 5s
		start_menu
	elif [[ "DIGISKR_IMAGE" == "true" ]] && [[ "DIGISKR_DEPLOYED" == "true" ]] && [[ "DIGISKR_RUNNING" == "false" ]]; then
		echo -e "${INFO} Digiskimmer is installed but not running, returning to the menu..."
		echo -e "${TIP} If you want to start Digiskimmer, select "Start Digiskimmer" in the menu."
		sleep 5s
		start_menu
	elif [[ "DIGISKR_IMAGE" == "true" ]] && [[ "DIGISKR_DEPLOYED" == "false" ]] && [[ "DIGISKR_RUNNING" == "false" ]]; then
		echo -e "${INFO} The Digiskimmer Docker image exists but undeployed, please wait..."
	elif [[ "DIGISKR_IMAGE" == "false" ]] && [[ "DIGISKR_DEPLOYED" == "false" ]] && [[ "DIGISKR_RUNNING" == "false" ]]; then
		echo -e "${INFO} Pulling Digiskimmer Docker image from registry, please wait..."
		if [[ "${COUNTRY}" != "CN" ]]; then
			if ! docker pull bclswl0827/digiskr:latest; then
				docker pull registry.cn-shanghai.aliyuncs.com/flydog-sdr/digiskr:latest
			fi
			docker tag bclswl0827/digiskr:latest registry.cn-shanghai.aliyuncs.com/flydog-sdr/digiskr:latest
			docker image rm bclswl0827/digiskr:latest
		else
			if ! docker pull registry.cn-shanghai.aliyuncs.com/flydog-sdr/digiskr:latest; then
				docker pull bclswl0827/digiskr:latest
				docker tag bclswl0827/digiskr:latest registry.cn-shanghai.aliyuncs.com/flydog-sdr/digiskr:latest
				docker image rm bclswl0827/digiskr:latest
			fi
		fi
	fi
	echo -e "${TIP} To use Dikiskimmer, let’s answer a few questions first."
	echo -e "${TIP} The generated configration will be stored at "/etc/digiskr/settings.py"."
	sleep 5s
	configure_digiskr
	echo -e "${INFO} Deploying Digiskimmer, please wait..."
	docker run -d \
		--env TIMEZONE="${TIMEZONE}" \
		--name digiskr \
		--network flydog-sdr \
		--restart always \
		--volume /etc/digiskr/settings.py:/opt/digiskr/settings.py \
		registry.cn-shanghai.aliyuncs.com/flydog-sdr/digiskr:latest &>/dev/null
	echo -e "${INFO} Digiskimmer has been successfully installed, exiting..."
	sleep 5s
	exit 0
}

# Check architecture
check_arch() {
	if [[ $(uname -m) != "armv7l" ]]; then
		echo -e "${ERROR} Only the armv7l architecture is supported now, exiting..."
		sleep 5s
		exit 1
	fi
}

# Check Docker
check_docker() {
	if [[ ! -f "/usr/bin/docker" ]]; then
		echo -e "${ERROR} Docker is not installed yet, exiting..."
		sleep 5s
		exit 1
	fi
}

# Check connectivity
check_net() {
	if [[ $(curl -I --silent baidu.com -w %{http_code} | tail -n1) != "200" ]]; then
		echo -e "${ERROR} Internet is not connected, exiting..."
		sleep 5s
		exit 1
	fi
}

# Check environment (get country and timezone)
check_env() {
	echo -e "${INFO} Getting country and timezone data, please wait..."
	if ! curl -fsSL -H 'Cache-Control: no-cache' -o /tmp/country_code.txt.tmp ipapi.co/country_code; then
		COUNTRY="CN"
	else
		COUNTRY="$(cat /tmp/country_code.txt.tmp)"
	fi
	if ! curl -fsSL -H 'Cache-Control: no-cache' -o /tmp/timezone.txt.tmp get.geojs.io/v1/ip/geo.json; then
		TIMEZONE="Asia/Shanghai"
	else
		TIMEZONE="$(cat /tmp/timezone.txt.tmp | cut -d ""\" -f16)"
	fi
	if ! curl -s -H 'Cache-Control: no-cache' -o /tmp/users_max.txt.tmp localhost:8073/status; then
		USERS_MAX="3"
	else
		USERS_MAX="$(grep -s "users_max" /tmp/users_max.txt.tmp | cut -d "=" -f2)"
	fi
	rm -rf /tmp/*.txt.tmp
}

# Check Digiskimmer
check_digiskr() {
	docker images | grep -q -s "/digiskr"
	if [[ $(echo $?) = "0" ]]; then
		DIGISKR_IMAGE="true"
		if [[ "x$(docker ps -q -a --filter name=^/digiskr$)" != "x" ]]; then
			DIGISKR_DEPLOYED="true"
			if [[ "$(docker inspect -f {{".State.Running"}} digiskr)" == "true" ]]; then
				DIGISKR_RUNNING="true"
			else
				DIGISKR_RUNNING="false"
			fi
		else
			DIGISKR_DEPLOYED="false"
		fi
	else
		DIGISKR_IMAGE="false"
		DIGISKR_DEPLOYED="false"
		DIGISKR_RUNNING="false"
	fi
}

# Check UID (should be running as root)
check_uid() {
	if [[ "${UID}" != "0" ]]; then
		echo -e "${ERROR} Not running with root, exiting..."
		sleep 5s
		exit 1
	fi
}

# Purge container logs
purge_logs() {
	echo
	for LOG in $(find /var/lib/docker/containers -name *-json.log); do
		echo -e "${INFO} Cleaning container logs: ${LOG}"
		cat /dev/null > ${LOG}
	done
	echo -e "${INFO} Done, returning to the menu..."
	sleep 5s
	start_menu
}

# Main interface
start_menu() {
	clear && echo && echo -e " Digiskimmer installation wizard ${Red_font_prefix}[v${VER}]${Font_color_suffix}

	==== FlyDog SDR Project | SDRotg.com ====
	==== Digiskimmer Installation Wizard ====

	=== Install & Uninstall ===

	${Green_font_prefix}1.${Font_color_suffix} Install Digiskimmer
	${Green_font_prefix}2.${Font_color_suffix} Uninstall Digiskimmer

	=== Contorl Digiskimmer ===

	${Green_font_prefix}3.${Font_color_suffix} Start Digiskimmer
	${Green_font_prefix}4.${Font_color_suffix} Stop Digiskimmer
	${Green_font_prefix}5.${Font_color_suffix} Restart Digiskimmer

	=== Configuration & Log ===

	${Green_font_prefix}6.${Font_color_suffix} Reconfigure Digiskimmer
	${Green_font_prefix}7.${Font_color_suffix} Purge Docker logs

	===========================
	${Green_font_prefix}8.${Font_color_suffix} Exit
	===========================" && echo
	read -p " Please choose [1-8]: " NUM
	case "${NUM}" in
		1)
		install_digiskr
		;;
		2)
		uninstall_digiskr
		;;
		3)
		control_digiskr start
		;;
		4)
		control_digiskr stop
		;;
		5)
		control_digiskr restart
		;;
		6)
		configure_digiskr
		control_digiskr restart
		;;
		7)
		purge_logs
		;;
		8)
		exit 0
		;;
		*)
		echo && echo -e "${ERROR} Enter the correct number [1-8]"
		sleep 5s
		start_menu
		;;
	esac
}

# Completely remove Digiskimmer
uninstall_digiskr() {
	echo
	echo -e "${INFO} Stopping container, please wait..."
	docker kill digiskr &>/dev/null
	echo -e "${INFO} Deleting container, please wait..."
	docker rm $(docker ps -q -a --filter name=^/digiskr$) &>/dev/null
	echo -e "${INFO} Removing image, please wait..."
	docker image rm $(docker images | grep "digiskr" | awk '{print $3}') &>/dev/null
	echo -e "${INFO} Digiskimmer has been successfully uninstalled, exiting..."
	sleep 5s
	exit 0
}

main() {
	clear && echo
	check_uid
	check_arch
	check_docker
	check_net
	check_env
	check_digiskr
	start_menu
}
main "$@"; exit
