#!/bin/bash
#source ~/.remoteit/credentials || true # littel hack to get R3_ACCESS_KEY_ID and R3_SECRET_ACCESS_KEY into the script

set -e

PLANT="${1}"
SSH_SERVICE_NAME="${2}"
R3_ACCESS_KEY_ID="CJX27WASA6U5SVBOJY6W"
R3_SECRET_ACCESS_KEY="6DvJ1up2yuCMQ6P2JMAmndRsMs0kRwyEOMhqNEPZ"

SECRET=`echo ${R3_SECRET_ACCESS_KEY} | base64 --decode`

HOST="api.remote.it"
URL_PATH="graphql/v1"
URL="https://${HOST}/${URL_PATH}"

VERB="POST"

CONTENT_TYPE="application/json"

LC_VERB=`echo "${VERB}" | tr '[:upper:]' '[:lower:]'`

DATE=$(LANG=en_US date -u "+%a, %d %b %Y %H:%M:%S %Z")

DATA='{ "query": "{ login { devices (size: 1000, from: 0) { items { id name tags { name } services { id name} } } } }" }'

SIGNING_STRING="(request-target): ${LC_VERB} /${URL_PATH}
host: ${HOST}
date: ${DATE}
content-type: ${CONTENT_TYPE}"

SIGNATURE=`echo -n "${SIGNING_STRING}" | openssl dgst -binary -sha256 -hmac "${SECRET}" | base64`

SIGNATURE_HEADER="Signature keyId=\"${R3_ACCESS_KEY_ID}\",algorithm=\"hmac-sha256\",headers=\"(request-target) host date content-type\",signature=\"${SIGNATURE}\""

RESPONSE=$(curl -s -X ${VERB} -H "Authorization:${SIGNATURE_HEADER}" -H "Date:${DATE}" -H "Content-Type:${CONTENT_TYPE}" ${URL} -d "${DATA}" --insecure)

DEVICE_ID=$(echo "${RESPONSE}" | jq -r --arg plant "${PLANT}" '.data.login.devices.items[] | select(.tags[]?.name == $plant) | .id')

SSH_SERVICE_ID=$(echo "${RESPONSE}" | jq -r --arg plant "${PLANT}" --arg service "${SSH_SERVICE_NAME}" '.data.login.devices.items[] | select(.tags[]?.name == $plant) | .services[] | select(.name == $service) | .id')

if [ -z "${DEVICE_ID}" ]; then
    echo "Error: Device with tag '${PLANT}' not found" >&2
    exit 1
fi

if [ -z "${SSH_SERVICE_ID}" ]; then
    echo "Error: ${SSH_SERVICE_NAME} service not found for device '${DEVICE_ID}'" >&2
    exit 1
fi

echo "DEVICE_ID: ${DEVICE_ID}"
echo "SSH_SERVICE_ID: ${SSH_SERVICE_ID}"
# connect using remote.it CLI
remoteit connection add --id "${SSH_SERVICE_ID}" --port 30001 --connectAtStart true