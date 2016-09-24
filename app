#!/bin/bash

usage ()
{
    echo
    echo "Usage: $(basename $0) [OPTIONS] NAME IMAGE SWARM"
    echo
    echo "Create or update a swarm application service"
    echo
    echo "NAME   service name"
    echo "IMAGE  repo/name:tag identifying the image"
    echo "SWARM  swarm to create the service on"
    echo
    echo "Options:"
    echo "  -n network    swarm overlay network the service connects to (default: dbnet)"
    echo "  -p port ...   ports to publish (without creating an ssh tunnel)"
    echo "  -t port ...   ports to publish (and create an ssh tunnel to)"
    echo "  -r replicas   number of replicas to run (default: 1)"
    echo
    echo "A volume appdata is mounted on /appdata"
    echo
}

while getopts "n:p:t:r:h" opt; do
    case $opt in
        n  ) NETWORK="$OPTARG";;
        p  ) PORTS+=("$OPTARG");;
        t  ) TUNNELS+=("$OPTARG");;
        r  ) REPLICAS="$OPTARG";;
        h  ) usage; exit;;
        \? ) echo "Unknown option: -$OPTARG" >&2; exit 1;;
        :  ) echo "Missing option argument for -$OPTARG" >&2; exit 1;;
        *  ) echo "Unimplemented option: -$OPTARG" >&2; exit 1;;
    esac
done
shift $((OPTIND -1))

NAME="$1"
TAG="$2"
ENV="$3"
if [ ! "$TAG" -o ! "$NAME" -o ! "$ENV" ]; then
    usage
    exit 1
fi
REPLICAS=${REPLICAS-1}
NETWORK=${NETWORK-dbnet}

DOCKER="docker-machine ssh ${ENV}-manager-1 sudo docker"

echo "* creating appdata..."
${DOCKER} volume create --name appdata

echo "* starting service..."
${DOCKER} service ps $NAME &>/dev/null
if [ "$?" = "0" ]; then
	${DOCKER} service update --image ${TAG} ${NAME}
	${DOCKER} service scale ${NAME}=${REPLICAS}
else
	PUBLISH=""
    for port in "${PORTS[@]}"; do
        PUBLISH="${PUBLISH} --publish ${port}:${port}"
    done
    for port in "${TUNNELS[@]}"; do
        PUBLISH="${PUBLISH} --publish ${port}:${port}"
    done
	${DOCKER} service create --name ${NAME} --replicas ${REPLICAS} --mount src=appdata,dst=/appdata --network ${NETWORK} ${PUBLISH} ${TAG}
fi

if [ "${TUNNELS[@]}" ]; then
    echo "* connecting..."
    sleep 15
    for port in "${TUNNELS[@]}"; do
        $(dirname "$0")/util/tunnel $ENV $port
    done
fi
