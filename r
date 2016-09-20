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

docker-machine ip ${ENV}-manager-1 1>/dev/null
if [ "$?" != "0" ]; then
	exit 1
fi

show ()
{
	$(dirname "$0")/util/tunnel $ENV 8080 /
}

if [ ! "${NUM}" ]; then
	show
	exit
fi

remove ()
{
	echo "* removing ${!#}..."
	eval $* 2>/dev/null
}

DOCKER="docker-machine ssh ${ENV}-manager-1 sudo docker"
for i in $(seq 0 $NUM)
do
	remove ${DOCKER} service rm db${i}
done
sleep 1
remove ${DOCKER} network rm dbnet
sleep 1
echo "* creating dbnet..."
${DOCKER} network create --driver overlay dbnet

for i in $(seq 0 $NUM)
do
	echo "* creating db${i}data..."
	${DOCKER} volume create --name db${i}data
	echo "* creating db${i}..."
	if [ "$i" = "0" ]; then
		${DOCKER} service create --name db0 --network dbnet --mount src=db0data,dst=/data --publish 8080:8080 rethinkdb
		sleep 10
	else
		${DOCKER} service create --name db${i} --network dbnet --mount src=db${i}data,dst=/data --mode global rethinkdb rethinkdb --join db0 --bind all
	fi
done

echo "* connecting..."
sleep 15
show
