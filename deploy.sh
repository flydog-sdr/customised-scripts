#!/usr/bin/env bash

# Define basic variables
BASE_PATH=$(cd `dirname $0`; pwd)
IMAGE_LIB="registry.cn-shanghai.aliyuncs.com/flydog-sdr/flydog-sdr"
IMAGE_TAG="latest"
LOCAL_IMAGE_ID=$(docker inspect -f {{".Id"}} ${IMAGE_LIB}:${IMAGE_TAG})
BACKUP_TAG="$(date +'%Y%m%d')"

backup_old_image() {
  docker tag ${LOCAL_IMAGE_ID} ${IMAGE_LIB}:${BACKUP_TAG}
  docker image rm ${IMAGE_LIB}:${IMAGE_TAG}
}

pull_latest_image() {
  if ! docker pull ${IMAGE_LIB}:${IMAGE_TAG}; then
    echo "error: Download failed! Trying to use backup node."
    if ! docker pull bclswl0827/flydog-sdr:${IMAGE_TAG}; then
      echo "error: Download failed! Falling back to deploy old instance."
      docker tag ${LOCAL_IMAGE_ID} ${IMAGE_LIB}:${IMAGE_TAG}
      docker image rm ${IMAGE_LIB}:${BACKUP_TAG}
      compatibility_settings
      saving_disk_space
      exit 1
    fi
    docker tag bclswl0827/flydog-sdr:${IMAGE_TAG} ${IMAGE_LIB}:${IMAGE_TAG}
    docker image rm bclswl0827/flydog-sdr:${IMAGE_TAG}
  fi
}

deploy_new_instance() {
  docker stop flydog-sdr
  docker network disconnect --force flydog-sdr flydog-sdr
  docker rm flydog-sdr
  docker run -d \
     --hostname flydog-sdr \
     --name flydog-sdr \
     --network flydog-sdr \
     --privileged \
     --publish 8073:8073 \
     --restart always \
     --volume kiwi.config:/root/kiwi.config \
     ${IMAGE_LIB}:${IMAGE_TAG}
  docker image rm -f ${LOCAL_IMAGE_ID}
}

compatibility_settings() {
  cat ${BASE_PATH}/self-update.txt > /usr/bin/updater.sh
  cat ${BASE_PATH}/VER > /etc/kiwi.config/_VER
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

saving_disk_space() {
  docker container prune -f
  docker image prune -f
  rm -rf ${BASE_PATH}
}

main() {
  backup_old_image
  pull_latest_image
  deploy_new_instance
  compatibility_settings
  saving_disk_space
  echo "Upgrade finished!"
}
main "$@"
