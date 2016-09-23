#!/bin/bash

usage ()
{
    echo
    echo "$(basename $0) creates or updates a swarm application service"
    echo
    echo "Usage:"
    echo
    echo "$(basename $0) [-n network] [-p port ...] [-t port ...] [-r replicas] <image> <name> <swarm>"
    echo "  creates a service named <name>, running Docker image tag <image> on the swarm named <swarm>"
    echo "  or updates the existing service to the new image tag"
    echo "  and/or scales it to the given number of replicas (default=1)"
    echo "  <image> takes the form repo/name:tag"
    echo "  -n specifies the swarm overlay network to run in"
    echo "  -p specifies any ports to publish (without creating an ssh tunnel)"
    echo "  -t specifies any ports to publish and create an ssh tunnel to"
    echo
}

while getopts "n:p:t:r:h" opt; do
    case $opt in
        n  ) NETWORK="--network $OPTARG";;
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

TAG="$1"
NAME="$2"
ENV="$3"
if [ ! "$TAG" -o ! "$NAME" -o ! "$ENV" ]; then
    usage
    exit 1
fi
REPLICAS=${REPLICAS-1}
DOCKER="docker-machine ssh ${ENV}-manager-1 sudo docker"

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
	${DOCKER} service create --name ${NAME} --replicas ${REPLICAS} ${NETWORK} ${PUBLISH} ${TAG}
fi

if [ "${TUNNELS[@]}" ]; then
    echo "* connecting..."
    sleep 15
    for port in "${TUNNELS[@]}"; do
        $(dirname "$0")/util/tunnel $ENV $port
    done
fi
