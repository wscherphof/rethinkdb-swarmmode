#!/bin/bash

ENV="$1"
if [ ! "$ENV" ]; then
	echo "Usage:"
	echo " $(basename $0) env"
	echo " $(basename $0) env create [number of servers per node; default=1]"
	exit 1
elif [[ "$2" = "create" ]]; then
	NUM=${3-1}
fi

res=$(docker-machine ip ${ENV}-manager-1)
if [ "$?" != "0" ]; then
	echo -n "${res}"
	exit 1
fi

portsdir="${HOME}/.rethinkdb_swarmmode/ports/"
mkdir -p ${portsdir}
if [ -e "${portsdir}${ENV}" ]; then
	PORT="$(cat ${portsdir}${ENV})"
else
	PORT="8080"
	if [ -e "${portsdir}latest" ]; then
		PORT="$(expr $(cat ${portsdir}latest) + 1)"
	fi
	echo "${PORT}" > "${portsdir}${ENV}"
	echo "${PORT}" > "${portsdir}latest"
fi

browse ()
{
	url="http://localhost:${PORT}"
	if [ "$(which xdg-open)" ]; then
		xdg-open "${url}"
	else
		open "${url}"
	fi
	echo "${ENV}: ${url}"
}

if [ ! "${NUM}" ]; then
	browse
	exit
fi

remove ()
{
	echo "* removing ${!#}..."
	eval $* 2>/dev/null
}

for i in $(seq 0 $NUM)
do
	remove docker-machine ssh ${ENV}-manager-1 sudo docker service rm db${i}
done
sleep 1
remove docker-machine ssh ${ENV}-manager-1 sudo docker network rm dbnet
sleep 1
echo "* creating dbnet..."
docker-machine ssh ${ENV}-manager-1 sudo docker network create --driver overlay dbnet

for i in $(seq 0 $NUM)
do
	echo "* creating db${i}data..."
	docker-machine ssh ${ENV}-manager-1 sudo docker volume create --name db${i}data
	echo "* creating db${i}..."
	if [ "$i" = "0" ]; then
		docker-machine ssh ${ENV}-manager-1 sudo docker service create --name db0 --network dbnet --mount src=db0data,dst=/data --publish 8080:8080 rethinkdb
		sleep 30
	else
		docker-machine ssh ${ENV}-manager-1 sudo docker service create --name db${i} --network dbnet --mount src=db${i}data,dst=/data --mode global rethinkdb rethinkdb --join db0 --bind all
	fi
done

echo "* connecting..."
sleep 5
docker-machine ssh ${ENV}-manager-1 -fNL ${PORT}:localhost:8080
browse
echo "* done"
