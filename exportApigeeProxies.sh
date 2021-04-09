#!/bin/bash

#########################################################################################################
#                                                                                                       #
#  author: Dejim Juang (dejim.juang@mulesoft.com)    		                                            #
#  description: Download all proxies from Apigee										                #
#  version: 1.0.0 (09/04/2021)                                                                          #
#  licence: GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)  #
#																										#
#  dependencies
#	* Download JQ		: https://stedolan.github.io/jq/
#                                                                                                       #
#########################################################################################################

### VARIABLES
DEBUG_MODE=1
WORKSPACE_DIR=/tmp
apigeeAPI=https://api.enterprise.apigee.com/v1/organizations

### FUNCTIONS
help(){
	echo "Usage: $0 [options...] " >&2
    echo
	echo "   -b=token, --bearer=token"
	echo "                 access token from an Apigee session"
	echo "   -d, --debug"
	echo "                 run script in debug mode"
    echo "   -o=org_name, --organization=org_name"
	echo "                 Apigee organization name to download proxies from"
	echo "   -p=password, --password=password"
	echo "                 username of an Apigee account"
	echo "   -u=user, --username=user"
	echo "                 username of an Apigee account"
	echo "   -h, --help    show this help "
    echo ""
    exit 1
}

print_debug(){
	if [ "${DEBUG_MODE}" -eq 1 ]
	then
		>&2 echo "[DEBUG] ${1}"
	fi
}

print_err(){
	>&2 echo ""
	>&2 echo "[ERROR] ${1}"
	>&2 echo ""
}

print_err_and_exit(){
	print_err "$1"
	kill -s TERM $TOP_PID
}

platform_login(){
	ap_username="$1"
	ap_password="$2"
	# read password from the console, user needs to enter it
	if [ "${ap_password}" = "" ]
	then
		read -sp 'Apigee Password: ' ap_password
	fi
    ACCESS_TOKEN=$(echo -n $username:$password | base64)
	>&2 echo ""
}

print_msg(){
	echo "[INFO] ${1}"
}

function log () {
    if [[ $quiet -eq 0 ]]; then
        echo "$@"
    fi
}

### MAIN SCRIPT LOGIC
for i in "$@"
do
	case $i in
        -b=*|--bearer=*)
			ACCESS_TOKEN="${i#*=}"
			shift # past argument=value
		;;
		-o=*|--organization=*)
			orgName="${i#*=}"
			shift # past argument=value
		;;
		-p=*|--password=*)
			password="${i#*=}"
			shift # past argument=value
		;;
		-u=*|--username=*)
			username="${i#*=}"
			shift # past argument=value
		;;
		-h|--help)
			help
		;;
		--default)
			help
		;;
		-d|--debug)
			DEBUG_MODE=1
			shift # past argument=value
		;;
		*)
			if [ ! "${i}" = "" ]
			then
				print_err_and_exit "Unknow option (${i}). Please use '-h|--help' to list valid parameters" 10
			fi
		;;
	esac
done

# then check if this is a login operation only, if user provided access token then
# there is no need of doing a login
if [ ! "${username}" = "" ] && [ "${ACCESS_TOKEN}" = "" ]
then
	platform_login "${username}" "${password}"
	print_debug "[main] token from login: ${ACCESS_TOKEN}"
	if [ "${ACCESS_TOKEN}" = "" ]
	then
		print_err_and_exit "[main] Error authenticating with Apigee"
	fi
fi

TARGET_DIRECTORY="${WORKSPACE_DIR}/${orgName}"

print_msg "Getting list of proxies from $apigeeAPI/$orgName/apis..."
jqParam=".[]"
proxies=$(curl -s $apigeeAPI/$orgName/apis -H "Authorization: Basic $ACCESS_TOKEN" -H "Accept: application/json"  --compressed | jq --raw-output "$jqParam")

while read -r api_name
do

    version=$(curl -s $apigeeAPI/$orgName/apis/$api_name/revisions -H "Authorization: Basic $ACCESS_TOKEN" -H "Accept: application/json"  --compressed | jq --raw-output "$jqParam")
    latest=$(log "$version" | tail -n1)
    print_msg "API Name: $api_name Version: $latest"

    finaldir=$TARGET_DIRECTORY/$api_name
    mkdir -p $finaldir

    curl -s $apigeeAPI/$orgName/apis/$api_name/revisions/$latest?format=bundle -H "Authorization: Basic $ACCESS_TOKEN" -H "Accept: application/json" --compressed > $finaldir/$api_name.zip 

done <<< "$proxies"

while read -r api_name
do
    finaldir=$TARGET_DIRECTORY/$api_name
    unzip "${finaldir}"/*.zip -d "${finaldir}/"
    rm -f "${finaldir}"/*.zip
done <<< "$proxies"