#!/bin/bash

ENV="$1"
USER="$2"
NAME="$3"
TAG="$4"
PORT="$5"
REPLICAS="${6-1}"
BROWSEPATH="$7"
PROTOCOL="$8"
BROWSER="$9"

DOCKER="docker-machine ssh ${ENV}-manager-1 sudo docker"

echo "* starting service..."
${DOCKER} service ps $NAME &>/dev/null
if [ "$?" = "0" ]; then
	${DOCKER} service update --image ${USER}/${NAME}:${TAG} ${NAME}
	${DOCKER} service scale ${NAME}=${REPLICAS}
else
	${DOCKER} service create --name ${NAME} --replicas ${REPLICAS} --network dbnet --publish ${PORT}:${PORT} ${USER}/${NAME}:${TAG}
fi

echo "* connecting..."
sleep 15
$(dirname "$0")/util/tunnel $ENV $PORT $BROWSEPATH $PROTOCOL $BROWSER
