#!/usr/bin/env bash

# Define basic variables
BASE_PATH="$(cd `dirname $0`; pwd)"
BACKUP_TAG="$(date +'%Y%m%d')"

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

# For rolling back when an error occurs
backup_image() {
  echo -e "${INFO} Backing up old image, please wait..."
  docker tag ${CURRENT_IMAGE_ID} flydog-sdr:backup-${BACKUP_TAG}
  docker image rm -f ${CURRENT_IMAGE_TAG} &>/dev/null
}

# Check country
check_country() {
  echo -e "${INFO} Getting country data, please wait..."
  if ! curl -fsSL -H 'Cache-Control: no-cache' -o /tmp/country_code.tmp ipapi.co/country_code; then
    COUNTRY="CN"
  else
    COUNTRY="$(cat /tmp/country_code.tmp)"
  fi
}

# Saving disk space
clean_work() {
  docker image rm -f flydog-sdr:backup-${BACKUP_TAG} &>/dev/null
  docker image prune -f &>/dev/null
  docker container prune -f &>/dev/null
  rm -rf ${BASE_PATH}
}

# Deploy newer version
deploy_new() {
  echo -e "${INFO} Deploying newer version, please wait..."
  docker stop flydog-sdr &>/dev/null
  docker network disconnect --force flydog-sdr flydog-sdr &>/dev/null
  docker rm flydog-sdr &>/dev/null
  docker run -d \
             --hostname flydog-sdr \
             --name flydog-sdr \
             --network flydog-sdr \
             --privileged \
             --publish 8073:8073 \
             --restart always \
             --volume kiwi.config:/root/kiwi.config \
             registry.cn-shanghai.aliyuncs.com/flydog-sdr/flydog-sdr:latest
  cat ${BASE_PATH}/self-update.txt > /usr/bin/updater.sh
  cat ${BASE_PATH}/VER > /etc/kiwi.config/_VER
}

# Execute upgrade
do_upgrade() {
  echo -e "${INFO} Pulling latest image, please wait..."
  if [[ "COUNTRY" != "CN" ]]; then
    if ! docker pull bclswl0827/flydog-sdr:latest &>/dev/null; then
      if ! docker pull registry.cn-shanghai.aliyuncs.com/flydog-sdr/flydog-sdr:latest &>/dev/null; then
        echo -e "${ERROR} Download failed, rolling back..."
        sleep 3s
        docker tag flydog-sdr:backup-${BACKUP_TAG} ${CURRENT_IMAGE_TAG}
        extra_script
        clean_work
        exit 1
      fi
    fi
    docker tag bclswl0827/flydog-sdr:latest registry.cn-shanghai.aliyuncs.com/flydog-sdr/flydog-sdr:latest
    docker image rm -f bclswl0827/flydog-sdr:latest &>/dev/null
  else
    if ! docker pull registry.cn-shanghai.aliyuncs.com/flydog-sdr/flydog-sdr:latest &>/dev/null; then
      if ! docker pull bclswl0827/flydog-sdr:latest &>/dev/null; then
        echo -e "${ERROR} Download failed, rolling back..."
        sleep 3s
        docker tag flydog-sdr:backup-${BACKUP_TAG} ${CURRENT_IMAGE_TAG}
        extra_script
        clean_work
        exit 1
      fi
      docker tag bclswl0827/flydog-sdr:latest registry.cn-shanghai.aliyuncs.com/flydog-sdr/flydog-sdr:latest
      docker image rm -f bclswl0827/flydog-sdr:latest &>/dev/null
    fi
  fi
  deploy_new
}

# Extra scripts for upgrading
extra_script() {
  # For FlyDog SDR under v1.4282
  #sed -e "s/login_fail_exit = true/login_fail_exit = false/g" \
  #    -i /etc/kiwi.config/frpc*
  # For FlyDog SDR under v1.4293
  # For FlyDog SDR under v1.433
  #if [[ ! -f /etc/kiwi.config/samples/timecode.test.au ]]; then
  #  if ! curl -L -q --retry 10 --retry-delay 10 --retry-max-time 60 -o /etc/kiwi.config/samples/timecode.test.au https://bclswl0827.coding.net/p/flydog-sdr/d/file/git/raw/master/timecode.test.au; then
  #    curl -L -q --retry 10 --retry-delay 10 --retry-max-time 60 -o /etc/kiwi.config/samples/timecode.test.au https://raw.githubusercontent.com/jks-prv/Beagle_SDR_GPS/master/unix_env/kiwi.config/samples/timecode.test.au
  #  fi
  #fi
  # For FlyDog SDR under v1.4541
  rm -rf /etc/kiwi.config/_VERSION
}

# Getting FlyDog SDR status
flydog_status() {
  echo -e "${INFO} Getting FlyDog SDR status, please wait..."
  CONTAINER_ID="$(docker ps -aq --filter name=^/flydog-sdr$)"
  CURRENT_IMAGE_ID="$(docker images | sed "s;flydog-sdr/admin;;g" | grep "flydog-sdr" | awk '{print $3}')"
  CURRENT_IMAGE_TAG="$(docker images | sed "s;flydog-sdr/admin;;g" | grep "flydog-sdr" | awk '{print $1":"$2}')"
}

main() {
  echo -e "${INFO} Upgrade detected, please wait..."
  sleep 3s
  check_country
  flydog_status
  backup_image
  do_upgrade
  extra_script
  clean_work
  echo -e "${INFO} Upgrade finished, exiting..."
  sleep 3s
}
main "$@"
