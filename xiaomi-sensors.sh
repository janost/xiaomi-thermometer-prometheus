#!/bin/bash

FILE_SENSORS="/etc/xiaomi-sensors"
TEXTFILE_COLLECTOR_DIR="/tmp/prom-textfile"
FILE_DATA="${TEXTFILE_COLLECTOR_DIR}/xiaomi-sensor-data.prom"
FILE_DATA_NEW="/tmp/xiaomi-sensor-data-new"

HCI_DEVICE="hci0"

SCRIPT_PATH="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"

FILE_LOCK="/tmp/$SCRIPT_PATH"
if [ -e "${FILE_LOCK}" ] && kill -0 "$(cat "${FILE_LOCK}")"; then
    exit 99
fi

trap 'rm -f "${FILE_LOCK}"; exit' INT TERM EXIT
echo $$ > "${FILE_LOCK}"

echo "Checking HCI device..."

if hciconfig "${HCI_DEVICE}" | grep -q UP; then
  echo "Device is already up."
else
  echo "Starting device..."
  hciconfig "${HCI_DEVICE}" up
fi

echo "Checking LE..."

if btmgmt info | grep "current settings" | grep -q " le "; then
  echo "LE is already enabled."
else
  echo "Enabling LE..."
  btmgmt le on
fi

rm "${FILE_DATA_NEW}"
mkdir -p "${TEXTFILE_COLLECTOR_DIR}"
while read -r item; do
    SENSOR=(${item//,/ })
    SENSOR_MAC="${SENSOR[0]}"
    SENSOR_NAME="${SENSOR[1]}"
    echo  "Sensor: $SENSOR_NAME ($SENSOR_MAC)"

    EXIT_CODE=1
    until [ ${EXIT_CODE} -eq 0 ]; do
        echo "  Getting ${SENSOR_NAME} Temperature and Humidity... "
        BT_DATA=$(timeout 30 /usr/bin/gatttool -b "${SENSOR_MAC}" --char-write-req --handle=0x10 -n 0100 --listen 2>&1 | grep -m 1 "Notification")
        BT_TEMP_TIMESTAMP=$(date +%s)
        EXIT_CODE=$?
        if [ ${EXIT_CODE} -ne 0 ]; then
            echo "failed, waiting 5 seconds before trying again"
            sleep 5
        fi
    done
    SENSOR_TEMP=$(echo "$BT_DATA" | tail -1 | cut -c 42-54 | xxd -r -p)
    SENSOR_HUMID=$(echo "$BT_DATA" | tail -1 | cut -c 64-74 | xxd -r -p)

    EXIT_CODE=1
    until [ ${EXIT_CODE} -eq 0 ]; do
        echo "  Getting ${SENSOR_NAME} Battery Level..."
        BT_DATA=$(/usr/bin/gatttool -b "${SENSOR_MAC}" --char-read --handle=0x18 2>&1 | cut -c 34-35)
        BT_BATT_TIMESTAMP=$(date +%s)
        EXIT_CODE=$?
        if [ ${EXIT_CODE} -ne 0 ]; then
            echo "failed, waiting 5 seconds before trying again"
            sleep 5
        fi
    done
    SENSOR_BATT=$(echo "ibase=16; ${BT_DATA^^}"  | bc)

    echo "  Temperature: ${SENSOR_TEMP}"
    echo "  Humidity: ${SENSOR_HUMID}"
    echo "  Battery Level: ${SENSOR_BATT}"

    echo "xiaomi_temperature{sensor=\"${SENSOR_NAME}\",mac=\"${SENSOR_MAC}\"} ${SENSOR_TEMP}" >> "${FILE_DATA_NEW}"
    echo "xiaomi_humidity{sensor=\"${SENSOR_NAME}\",mac=\"${SENSOR_MAC}\"} ${SENSOR_HUMID}" >> "${FILE_DATA_NEW}"
    echo "xiaomi_battery{sensor=\"${SENSOR_NAME}\",mac=\"${SENSOR_MAC}\"} ${SENSOR_BATT}" >> "${FILE_DATA_NEW}"
    echo "xiaomi_temperature_updated{sensor=\"${SENSOR_NAME}\",mac=\"${SENSOR_MAC}\"} ${BT_TEMP_TIMESTAMP}" >> "${FILE_DATA_NEW}"
    echo "xiaomi_humidity_updated{sensor=\"${SENSOR_NAME}\",mac=\"${SENSOR_MAC}\"} ${BT_TEMP_TIMESTAMP}" >> "${FILE_DATA_NEW}"
    echo "xiaomi_battery_updated{sensor=\"${SENSOR_NAME}\",mac=\"${SENSOR_MAC}\"} ${BT_BATT_TIMESTAMP}" >> "${FILE_DATA_NEW}"
done < "$FILE_SENSORS"

rm "${FILE_DATA}"
mv "${FILE_DATA_NEW}" "${FILE_DATA}"

echo "Finished."

