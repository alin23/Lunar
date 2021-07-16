#!/bin/sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

mkdir -p "/tmp/lunarsensor/$BOARD"
cd "/tmp/lunarsensor/$BOARD"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

LOG_PATH=${LOG_PATH:-/tmp/lunar-sensor-install.log}

echo "" > "$LOG_PATH"
echo "Installing latest Python pip..." | tee -a "$LOG_PATH"
echo "" | tee -a "$LOG_PATH"
echo "" | tee -a "$LOG_PATH"
/usr/bin/python3 -m pip install --user -U pip 2>&1 | tee -a "$LOG_PATH"

echo "" | tee -a "$LOG_PATH"
echo "Installing ESPHome..." | tee -a "$LOG_PATH"
echo "" | tee -a "$LOG_PATH"
echo "" | tee -a "$LOG_PATH"
/usr/bin/python3 -m pip install --user esphome 2>&1 | tee -a "$LOG_PATH"

echo "" | tee -a "$LOG_PATH"
echo "Compiling and uploading firmware to $ESP_DEVICE ($BOARD) ..." | tee -a "$LOG_PATH"
echo "" | tee -a "$LOG_PATH"
echo "SSID=$WIFI_SSID" | tee -a "$LOG_PATH"
echo "PASSWORD=$WIFI_PASSWORD" | tee -a "$LOG_PATH"
echo "" | tee -a "$LOG_PATH"
/usr/bin/python3 -m esphome -s ssid "$WIFI_SSID" -s password "$WIFI_PASSWORD" -s board "${BOARD:-esp32dev}" run "$DIR/lunar.yaml" --no-logs --device "$ESP_DEVICE" 2>&1 | tee -a "$LOG_PATH"
