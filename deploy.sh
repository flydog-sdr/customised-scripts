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
    echo "error: Download failed! Falling back to deploy old instance."
    docker tag ${LOCAL_IMAGE_ID} ${IMAGE_LIB}:${IMAGE_TAG}
    docker image rm ${IMAGE_LIB}:${BACKUP_TAG}
    compatibility_settings
  fi
}

deploy_new_instance() {
  docker stop flydog-sdr
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
  sed -e "s/login_fail_exit = true/login_fail_exit = false/g" \
      -i /etc/kiwi.config/frpc*
  cat ${BASE_PATH}/self-update.txt > /usr/bin/updater.sh
  cat ${BASE_PATH}/VER > /etc/kiwi.config/_VERSION
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
