#!/bin/sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

mkdir -p "/tmp/lunarsensor/$BOARD"
cd "/tmp/lunarsensor/$BOARD"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

LOG_PATH=${LOG_PATH:-/tmp/lunar-sensor-install.log}
BOARD="${BOARD:-esp32dev}"

if [[ "$BOARD" == "metroesp32-s2" ]]; then
    PLATFORM_VERSION="${PLATFORM_VERSION:-https://static.lunar.fyi/platform-espressif32-b331f75383faaa7bc8ee971b0cdb83177feb8284.zip}"
    PLATFORM="${PLATFORM:-ESP32}"
    SDA="${SDA:-33}"
    SCL="${SCL:-34}"
elif [[ "$BOARD" == "nodemcuv2" || "$BOARD" == "d1_mini" || "$BOARD" == "d1_mini_lite" || "$BOARD" == "d1_mini_pro" || "$BOARD" == "nodemcu" ]]; then
    PLATFORM_VERSION="${PLATFORM_VERSION:-platformio/espressif8266@2.6.2}"
    PLATFORM="${PLATFORM:-ESP8266}"
    SDA="${SDA:-D2}"
    SCL="${SCL:-D1}"
elif [[ "$BOARD" == "esp32dev" || "$BOARD" == "lolin32" || "$BOARD" == "lolin32_lite" || "$BOARD" == "nodemcu-32s" ]]; then
    PLATFORM_VERSION="${PLATFORM_VERSION:-platformio/espressif32@3.2.0}"
    PLATFORM="${PLATFORM:-ESP32}"
    SDA="${SDA:-19}"
    SCL="${SCL:-23}"
else
    PLATFORM_VERSION="${PLATFORM_VERSION:-platformio/espressif8266@2.6.2}"
    PLATFORM="${PLATFORM:-ESP8266}"
    SDA="${SDA:-GPIO4}"
    SCL="${SCL:-GPIO5}"
fi

echo "" > "$LOG_PATH"
echo "Installing latest Python pip..." | tee -a "$LOG_PATH"
echo "" | tee -a "$LOG_PATH"
echo "" | tee -a "$LOG_PATH"
/usr/bin/python3 -m pip install --user -U pip 2>&1 | tee -a "$LOG_PATH"

echo "" | tee -a "$LOG_PATH"
echo "Installing ESPHome..." | tee -a "$LOG_PATH"
echo "" | tee -a "$LOG_PATH"
echo "" | tee -a "$LOG_PATH"
/usr/bin/python3 -m pip install --user --no-cache https://static.lunar.fyi/esphome-dev.zip 2>&1 | tee -a "$LOG_PATH"

echo "" | tee -a "$LOG_PATH"
echo "Compiling and uploading firmware to $ESP_DEVICE ($BOARD) ..." | tee -a "$LOG_PATH"
echo "" | tee -a "$LOG_PATH"
echo "SSID=$WIFI_SSID" | tee -a "$LOG_PATH"
echo "PASSWORD=$WIFI_PASSWORD" | tee -a "$LOG_PATH"
echo "" | tee -a "$LOG_PATH"

echo /usr/bin/python3 -m esphome \
    -s ssid "$WIFI_SSID" \
    -s password "$WIFI_PASSWORD" \
    -s board "$BOARD" \
    -s platform "$PLATFORM" \
    -s platform_version "$PLATFORM_VERSION" \
    -s sda "$SDA" \
    -s scl "$SCL" \
    run "$DIR/lunar.yaml" --no-logs --device "$ESP_DEVICE" 2>&1 | tee -a "$LOG_PATH"

/usr/bin/python3 -m esphome \
    -s ssid "$WIFI_SSID" \
    -s password "$WIFI_PASSWORD" \
    -s board "$BOARD" \
    -s platform "$PLATFORM" \
    -s platform_version "$PLATFORM_VERSION" \
    -s sda "$SDA" \
    -s scl "$SCL" \
    run "$DIR/lunar.yaml" --no-logs --device "$ESP_DEVICE" 2>&1 | tee -a "$LOG_PATH"
