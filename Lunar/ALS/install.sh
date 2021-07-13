#!/bin/sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

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
echo "Compiling and uploading firmware to $ESP_DEVICE ..." >> "$LOG_PATH"
echo "" >> "$LOG_PATH"
echo "SSID=$WIFI_SSID" >> "$LOG_PATH"
echo "PASSWORD=$WIFI_PASSWORD" >> "$LOG_PATH"
echo "" >> "$LOG_PATH"
/usr/bin/python3 -m esphome -s ssid "$WIFI_SSID" -s password "$WIFI_PASSWORD" "$DIR/lunar.yaml" run --no-logs --device "$ESP_DEVICE" >>"$LOG_PATH" 2>>"$LOG_PATH"
