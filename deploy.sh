#!/bin/bash -e

# Define global environment variables
IMAGE_TAG="registry.cn-shanghai.aliyuncs.com/flydog-sdr/flydog-sdr:latest"
LOCAL_IMAGE_ID=$(docker inspect -f {{".Id"}} ${IMAGE_TAG})

# Remove previous container and old image
docker rm -f flydog-sdr
docker image rm -f ${LOCAL_IMAGE_ID}

# Pull new image and deploy
docker run -d \
   --hostname flydog-sdr \
   --name flydog-sdr \
   --network flydog-sdr \
   --privileged \
   --publish 8073:8073 \
   --restart always \
   --volume kiwi.config:/root/kiwi.config \
   ${IMAGE_TAG}

# Update Frpc configuration for old version
sed -e "s/login_fail_exit = true/login_fail_exit = false/g" \
    -i /etc/kiwi.config/frpc*

# Self-update for /usr/bin/updater.sh
cat /tmp/customised-scripts/self-update.txt > /usr/bin/updater.sh

# Purge previous image for saving disk space
echo "Purging all unused or dangling images, containers."
docker container prune -f
docker image prune -f

# Finish upgrading stage
rm -rf /tmp/customised-scripts
echo "Upgrade finished!"

exit 0