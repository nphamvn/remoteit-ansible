#!/usr/bin/env bash
set -euo pipefail

SSH_SERVICE_NAME=${SSH_SERVICE_NAME:-"SSH"}
echo "Finding ssh service id for plant '${PLANT}' using service name '${SSH_SERVICE_NAME}'"

SECRET=$(
  printf '%s' "$R3_SECRET_ACCESS_KEY" \
  | tr '_-' '/+' \
  | base64 --decode
)

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

echo "Adding remoteit connection for SSH service id '${SSH_SERVICE_ID}' on local port '${LOCAL_PORT}'"
remoteit connection add --id ${SSH_SERVICE_ID} --port ${LOCAL_PORT} --name "ssh" --connectAtStart true

# Wait for connection to be established
INTERVAL=5
TIMEOUT=60
ELAPSED=0

while true; do
  if remoteit status -j | jq -e '
    .data.connections[]
    | select(.addressHost=="ssh.at.remote.it"
             and .addressPort==30001
             and .state==4)
  ' > /dev/null; then
    echo "✅ Connection ssh.at.remote.it:30001 is CONNECTED (state=4)"
    break
  fi

  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    echo "❌ Timeout after ${TIMEOUT}s waiting for connection"
    exit 1
  fi

  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
done

sleep 2