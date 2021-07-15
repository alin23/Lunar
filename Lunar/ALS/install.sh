#!/bin/sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

mkdir -p "/tmp/lunarsensor/$BOARD"
cd "/tmp/lunarsensor/$BOARD"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

LOG_PATH=${LOG_PATH:-/tmp/lunar-sensor-install.log}

echo "Installing latest Python pip..." > "$LOG_PATH"
echo "" >> "$LOG_PATH"
echo "" >> "$LOG_PATH"
/usr/bin/python3 -m pip install --user -U pip >>"$LOG_PATH" 2>>"$LOG_PATH"

echo "" >> "$LOG_PATH"
echo "Installing ESPHome..." >> "$LOG_PATH"
echo "" >> "$LOG_PATH"
echo "" >> "$LOG_PATH"
/usr/bin/python3 -m pip install --user esphome >>"$LOG_PATH" 2>>"$LOG_PATH"

echo "" >> "$LOG_PATH"
echo "Compiling and uploading firmware to $ESP_DEVICE ($BOARD) ..." >> "$LOG_PATH"
echo "" >> "$LOG_PATH"
echo "SSID=$WIFI_SSID" >> "$LOG_PATH"
echo "PASSWORD=$WIFI_PASSWORD" >> "$LOG_PATH"
echo "" >> "$LOG_PATH"
/usr/bin/python3 -m esphome -s ssid "$WIFI_SSID" -s password "$WIFI_PASSWORD" -s board "${BOARD:-esp32dev}" run "$DIR/lunar.yaml" --no-logs --device "$ESP_DEVICE" >>"$LOG_PATH" 2>>"$LOG_PATH"
