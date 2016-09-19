#!/bin/bash

USER="$1"
NAME="$2"
TAG="$3"
ENV="$4"

echo "* starting service..."
docker-machine ssh ${ENV}-manager-1 docker service create --name ${NAME} --replicas 6 --network dbnet --publish 9090:9090 ${USER}/${NAME}:${TAG} 2>/dev/null
if [ "$?" != "0" ]; then
	docker-machine ssh ${ENV}-manager-1 docker service update --image ${USER}/${NAME}:${TAG} ${NAME}
fi

echo "* connecting..."
sleep 30
docker-machine ssh ${ENV}-manager-1 -fNL 9090:localhost:9090
echo "* app says:"
curl http://localhost:9090/bar
