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
