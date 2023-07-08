#!/bin/zsh

set -xe

LOG_PATH=${LOG_PATH:-/tmp/lunar-sensor-install.log}
echo "" > "$LOG_PATH"

DIR="${0:a:h}"
BOARD_DIR="/tmp/lunarsensor/$BOARD"
SENSOR="${SENSOR:-tsl2591}"

mkdir -p "$BOARD_DIR" || true
cp -RL "$DIR/install.sh" "$BOARD_DIR/" || true
echo /usr/bin/python3 -c "open('$BOARD_DIR/lunar.yaml', 'w')\
    .write(\
        open('$DIR/lunar.yaml')\
        .read()\
        .replace('SENSOR_DEFINITION', open('$DIR/$SENSOR.yaml').read())\
    )" >> "$LOG_PATH"
/usr/bin/python3 -c "open('$BOARD_DIR/lunar.yaml', 'w')\
    .write(\
        open('$DIR/lunar.yaml')\
        .read()\
        .replace('SENSOR_DEFINITION', open('$DIR/$SENSOR.yaml').read())\
    )"
cd "$BOARD_DIR"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

BOARD="${BOARD:-esp32dev}"

if [[ "$BOARD" == "sparkfun_esp32s2_thing_plus" ]]; then
    PLATFORM_VERSION="${PLATFORM_VERSION:-platformio/espressif32@5.3.0}"
    PLATFORM="${PLATFORM:-ESP32}"
    SDA="${SDA:-01}"
    SCL="${SCL:-02}"
elif [[ "$BOARD" == "adafruit_metro_esp32s2" || "$BOARD" == "adafruit_funhouse_esp32s2"  || "$BOARD" == "adafruit_feather_esp32s2_tft"  || "$BOARD" == "adafruit_magtag29_esp32s2" ]]; then
    PLATFORM_VERSION="${PLATFORM_VERSION:-platformio/espressif32@5.3.0}"
    PLATFORM="${PLATFORM:-ESP32}"
    SDA="${SDA:-33}"
    SCL="${SCL:-34}"
elif [[ "$BOARD" == "nodemcuv2" || "$BOARD" == "d1_mini" || "$BOARD" == "d1_mini_lite" || "$BOARD" == "d1_mini_pro" || "$BOARD" == "nodemcu" ]]; then
    PLATFORM_VERSION="${PLATFORM_VERSION:-platformio/espressif8266@4.0.1}"
    PLATFORM="${PLATFORM:-ESP8266}"
    SDA="${SDA:-D2}"
    SCL="${SCL:-D1}"
elif [[ "$BOARD" == "esp32dev" || "$BOARD" == "lolin32" || "$BOARD" == "lolin32_lite" || "$BOARD" == "nodemcu-32s" ]]; then
    PLATFORM_VERSION="${PLATFORM_VERSION:-platformio/espressif32@5.3.0}"
    PLATFORM="${PLATFORM:-ESP32}"
    SDA="${SDA:-19}"
    SCL="${SCL:-23}"
else
    PLATFORM_VERSION="${PLATFORM_VERSION:-platformio/espressif8266@4.0.1}"
    PLATFORM="${PLATFORM:-ESP8266}"
    SDA="${SDA:-GPIO4}"
    SCL="${SCL:-GPIO5}"
fi

echo "Installing latest Python pip..." | tee -a "$LOG_PATH"
echo "" | tee -a "$LOG_PATH"
echo "" | tee -a "$LOG_PATH"
/usr/bin/python3 -m pip install --user -U pip 2>&1 | tee -a "$LOG_PATH"
if [[ $PIPESTATUS ]]; then
    echo "\${PIPESTATUS[0]} == ${PIPESTATUS[0]}"
    test ${PIPESTATUS[0]} == 0 || exit ${PIPESTATUS[0]}
fi

echo "" | tee -a "$LOG_PATH"
echo "Installing ESPHome..." | tee -a "$LOG_PATH"
echo "" | tee -a "$LOG_PATH"
echo "" | tee -a "$LOG_PATH"
/usr/bin/python3 -m pip install --user esphome==2023.6.3 2>&1 | tee -a "$LOG_PATH"
if [[ $PIPESTATUS ]]; then
    echo "\${PIPESTATUS[0]} == ${PIPESTATUS[0]}"
    test ${PIPESTATUS[0]} == 0 || exit ${PIPESTATUS[0]}
fi

echo "" | tee -a "$LOG_PATH"
echo "Compiling and uploading firmware to $ESP_DEVICE ($BOARD) ..." | tee -a "$LOG_PATH"
echo "" | tee -a "$LOG_PATH"
echo "SSID=$WIFI_SSID" | tee -a "$LOG_PATH"
echo "PASSWORD=$WIFI_PASSWORD" | tee -a "$LOG_PATH"
echo "SENSOR=$SENSOR" | tee -a "$LOG_PATH"
echo "" | tee -a "$LOG_PATH"

echo /usr/bin/python3 -m esphome \
    -s ssid "$WIFI_SSID" \
    -s password "$WIFI_PASSWORD" \
    -s board "$BOARD" \
    -s platform "$PLATFORM" \
    -s platform_version "$PLATFORM_VERSION" \
    -s sda "$SDA" \
    -s scl "$SCL" \
    run "$BOARD_DIR/lunar.yaml" --no-logs --device "$ESP_DEVICE" 2>&1 | tee -a "$LOG_PATH"
if [[ $PIPESTATUS ]]; then
    echo "\${PIPESTATUS[0]} == ${PIPESTATUS[0]}"
    test ${PIPESTATUS[0]} == 0 || exit ${PIPESTATUS[0]}
fi

/usr/bin/python3 -m esphome \
    -s ssid "$WIFI_SSID" \
    -s password "$WIFI_PASSWORD" \
    -s board "$BOARD" \
    -s platform "$PLATFORM" \
    -s platform_version "$PLATFORM_VERSION" \
    -s sda "$SDA" \
    -s scl "$SCL" \
    run "$BOARD_DIR/lunar.yaml" --no-logs --device "$ESP_DEVICE" 2>&1 | tee -a "$LOG_PATH"
if [[ $PIPESTATUS ]]; then
    echo "\${PIPESTATUS[0]} == ${PIPESTATUS[0]}"
    test ${PIPESTATUS[0]} == 0 || exit ${PIPESTATUS[0]}
fi
