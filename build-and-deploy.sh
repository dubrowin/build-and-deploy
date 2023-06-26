#!/bin/bash

################################
## Script to build and push
## Docker images to ECR and
## Lambda
##
## By: Shlomo Dubrowin
## On: Jun 23, 2023
## Ver: 0.01
################################

## To Do Next
#- Add CLI Commands for different pieces
#- Add pieces to create ECR Private Repo
#- And Create new Lambda storing the required pieces

################################
## Variables
################################
TMP="/tmp/$( basename "$0" ).tmp"
TMP1="/tmp/$( basename "$0" ).1.tmp"
echo -e "\c" > $TMP1
BUILD=""
EXEC=""
SHEL=""
PUSH=""
SETLAM=""
DEBUG="Y"
BASEDIR="/home/$USER"

################################
## Functions
################################

function Help {
	echo -e "\n\tusage: $(basename $0) 
\t\t[ -b | --build-docker ]
\t\t[ -e | --execute ]
\t\t[ -s | --shell ]
\t\t[ -p | --push2ecr ]
\t\t[ -l | --set-lambda2use ]
\t\t[ -a | --all (Default, does not include execute) ]
\t\t[Container Directory]

\t\t[-D | --debug] 
\t\t[-h | --help] 
\n"
        exit
}

function Debug {
        if [ "$DEBUG" == "Y" ]; then
                if [ ! -z "$CRON" ]; then
                        # Cron, output only to log
                        logger -t $( basename "$0") "$$ $1"
                else
                        # Not Cron, output to CLI and log
                        echo -e "$( date +"%b %d %H:%M:%S" ) running $SECONDS secs: $1"
                        logger -t $( basename "$0") "$$ $1"
                fi
        fi
}

function CheckContainer {
	if [ -z $CONTAINER ]; then	
		Debug "No container set ($CONTAINER), executing Menu"
		Menu
	fi
	if [ ! -z $CONTAINER ]; then
		# Verify the Directory
		if [ ! -d "$BASEDIR/$CONTAINER" ]; then
			echo "Error: $BASEDIR/$CONTAINER is not a directory on the system"
			Debug "Error: $BASEDIR/$CONTAINER is not a directory on the system"
			exit 1
		fi
	fi
}

function BuildDocker {
	cd $BASEDIR/$CONTAINER/

	DOCKERFILE=`ls | grep docker-file`

	# Build
	Debug "Where am I: $(pwd)"
	#newgrp docker
	docker build -f $DOCKERFILE -t $CONTAINER .

	# Tag as Latest
	docker tag ${CONTAINER}:latest 524365920037.dkr.ecr.us-east-2.amazonaws.com/${CONTAINER}:latest

	cd -
}

function PushDocker2ECR {
	# ECR Credentials
	aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 524365920037.dkr.ecr.us-east-2.amazonaws.com && echo "Login Successful" || echo "ERROR: Logging In"

	# Push to ECR
	docker push 524365920037.dkr.ecr.us-east-2.amazonaws.com/${CONTAINER}:latest
}

function SetLambda2UseECR {
	## Update Lambda to use Latest ECR
	ECR_REPO_FUNCTION_PREFIX="524365920037.dkr.ecr.us-east-2.amazonaws.com/${CONTAINER}"

	LAMBDA=`cat $BASEDIR/$CONTAINER/lambda-function.txt`
	Debug "Pushing $CONTAINER to be used by $LAMBDA"
	aws lambda update-function-code --function-name $LAMBDA --image-uri $(echo "$ECR_REPO_FUNCTION_PREFIX@$(aws ecr batch-get-image --repository-name ${CONTAINER} --image-ids imageTag=latest | jq -e '.images[0].imageId.imageDigest' | tr -d '"')") &> /dev/null

}

function DockerShell {
	CheckContainer
	Debug "docker exec -it $CONTAINER bash"
	docker exec -it $CONTAINER bash
}

function Menu {
	################################
	## Menu System
	################################
	find $BASEDIR/ -type d | cut -d / -f 4- | grep -v "^$\|^\./\.\|^\.$\|^\.\|scripts" | cut -d / -f 2 > $TMP

	echo -e "\n\tWhich image to deploy?\n"
	while read LINE; do
        	let "COUNT = $COUNT + 1"
        	echo -e "$COUNT \t $LINE" >> $TMP1
	done < $TMP

	if [ ! -z $1 ]; then
        	CUST="$1"
	else
        	cat $TMP1
        	echo -e "\nq \t Quit"
        	echo -e "\nWhich Container? \c"

        	read CUST
	fi

	re='^[0-9]+$'
	if ! [[ $CUST =~ $re ]]; then
        	echo "exiting"
        	exit
	fi

	if [ $CUST -gt $COUNT ]; then
        	echo "not a valid request, exiting"
        	exit 1
	fi

	CONTAINER=`cat -n $TMP | sed "${CUST}!d" | awk '{print $2}'`
	#echo "CONTAINER $CONTAINER"
	echo -e "Selected: \c\t $CONTAINER"
}

function Execute {
	docker run -i -t $CONTAINER
}

################################
## CLI Options
################################

if [ -z != "$1" ]; then
        while [ "$1" != "" ]; do
        case $1 in
                -D | --debug )
                        DEBUG="Y"
                        Debug "Setting Debug"
                        ;;
                -b | --build-docker )
			BUILD="Y"
                        ;;
		-e | --execute )
			EXEC="Y"
			;;
		-s | --shell )
			SHEL="Y"
			;;
                -p | --push2ecr )
			PUSH="Y"
                        ;;
                -l | --set-lambda2use )
			SETLAM="Y"
                        ;;
                -h | --help )
                        Help
                        ;;
                -a | -all )
			BUILD="Y"
			PUSH="Y"
			SETLAM="Y"
                        ;;
		*)
			CONTAINER="$1"
			;;
        esac
        shift
        done
fi


################################
## Main Code
################################
CheckContainer
if [ "$BUILD" == "" ] && [ "$EXEC" == "" ] && [ "$PUSH" == "" ] && [ "$SETLAM" == "" ] && [ "$SHEL" == "" ]; then
	Debug "No selections made, setting STANDARD"
	BUILD=Y
	PUSH=Y
	SETLAM=Y
fi
if [ "$BUILD" == "Y" ]; then
	Debug "Executing BuildDocker"
	BuildDocker
fi
if [ "$SHEL" == "Y" ]; then
	Debug "Executing Shell"
	DockerShell
fi
if [ "$EXEC" == "Y" ]; then
	Debug "Executing Execute"
	Execute
fi
if [ "$PUSH" == "Y" ]; then
	Debug "Executing PushDocker2ECR"
	PushDocker2ECR
fi
if [ "$SETLAM" == "Y" ]; then
	Debug "Executing SetLambda2UseECR"
	SetLambda2UseECR
fi

