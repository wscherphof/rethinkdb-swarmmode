#!/bin/bash

ENV="$1"
USER="$2"
NAME="$3"
TAG="$4"
PORT="$5"
REPLICAS="${6-1}"
BROWSER="$7"
PROTOCOL="$8"
BROWSEPATH="$9"

echo "* starting service..."
docker-machine ssh tst-manager-1 sudo docker service ps $NAME &>/dev/null
if [ "$?" = "0" ]; then
	docker-machine ssh ${ENV}-manager-1 sudo docker service update --image ${USER}/${NAME}:${TAG} ${NAME}
else
	docker-machine ssh ${ENV}-manager-1 sudo docker service create --name ${NAME} --replicas ${REPLICAS} --network dbnet --publish ${PORT}:${PORT} ${USER}/${NAME}:${TAG}
fi

echo "* connecting..."
sleep 15
$(dirname "$0")/tunnel $ENV $PORT $BROWSER $PROTOCOL $BROWSEPATH
