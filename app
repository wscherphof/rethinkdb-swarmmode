#!/bin/bash

usage () { echo "./app -t wscherphof/expeertise:0.1 -p 9090 -p 10443 -r 6 -b / -e dev expeertise"; }

while getopts "t:p:e:a:r:b:P:B:" opt; do
    case $opt in
        t  ) TAG="$OPTARG";;
        e  ) ENV="$OPTARG";;
        r  ) REPLICAS="$OPTARG";;
        p  ) PORTS+=("$OPTARG");;
        b  ) BROWSEPATH="$OPTARG";;
        P  ) PROTOCOL="$OPTARG";;
        B  ) BROWSER="$OPTARG";;
        # h  ) usage; exit;;
        # \? ) echo "Unknown option: -$OPTARG" >&2; exit 1;;
        # :  ) echo "Missing option argument for -$OPTARG" >&2; exit 1;;
        # *  ) echo "Unimplemented option: -$OPTARG" >&2; exit 1;;
    esac
done
shift $((OPTIND -1))

NAME="$1"

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
	${DOCKER} service create --name ${NAME} --replicas ${REPLICAS} --network dbnet ${PUBLISH} ${TAG}
fi

echo "* connecting..."
sleep 15
for port in "${PORTS[@]}"; do
	$(dirname "$0")/util/tunnel $ENV $port $BROWSEPATH $PROTOCOL $BROWSER
done
