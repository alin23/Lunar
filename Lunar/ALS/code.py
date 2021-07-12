import time

import adafruit_displayio_ssd1306
import adafruit_tcs34725
import adafruit_tsl2561
import adafruit_tsl2591
import adafruit_vcnl4040
import adafruit_veml7700
import board
import busio
import displayio
import supervisor
import terminalio
from adafruit_display_text import label

displayio.release_displays()
i2c = busio.I2C(board.GP19, board.GP18)

WIDTH = 128
HEIGHT = 64
BORDER = 3
FONT_SIZE = 10


def try_sensor(sensor_class, i2c_bus, configure):
    try:
        sensor = sensor_class(i2c_bus)

        print("Configuring Lux Sensor...")
        configure(sensor)
        print("Finished configuring Lux Sensor.")

        return sensor
    except:
        return None


def configure_tsl2561(sensor):
    sensor.gain = 0  # 1x
    sensor.integration_time = 2  # 402ms


def configure_tsl2591(sensor):
    sensor.gain = adafruit_tsl2591.GAIN_LOW  # 1x
    sensor.integration_time = adafruit_tsl2591.INTEGRATIONTIME_400MS


def configure_tcs34725(sensor):
    sensor.gain = 1  # 1x
    sensor.integration_time = 400  # 400ms


def configure_veml7700(sensor):
    sensor.light_gain = adafruit_veml7700.VEML7700.ALS_GAIN_1_4
    sensor.light_integration_time = adafruit_veml7700.VEML7700.ALS_400MS


def configure_vcnl4040(sensor):
    sensor.light_integration_time = adafruit_vcnl4040.VCNL4040.ALS_320MS


def lux_sensor(i2c_bus):
    sensor = (
        try_sensor(adafruit_veml7700.VEML7700, i2c_bus, configure_veml7700)
        or try_sensor(adafruit_tsl2591.TSL2591, i2c_bus, configure_tsl2591)
        or try_sensor(adafruit_tsl2561.TSL2561, i2c_bus, configure_tsl2561)
        or try_sensor(adafruit_tcs34725.TCS34725, i2c_bus, configure_tcs34725)
        or try_sensor(adafruit_vcnl4040.VCNL4040, i2c_bus, configure_vcnl4040)
    )

    # Print chip info
    print("Sensor type = {}".format(sensor.__class__.__name__))

    return sensor


def oled_display(i2c_bus, width, height, border):
    display_bus = displayio.I2CDisplay(i2c_bus, device_address=0x3C, reset=board.GP21)
    display = adafruit_displayio_ssd1306.SSD1306(
        display_bus, width=width, height=height
    )

    # Make the display context
    splash = displayio.Group(max_size=FONT_SIZE)
    display.show(splash)

    color_bitmap = displayio.Bitmap(width, height, 1)
    color_palette = displayio.Palette(1)
    color_palette[0] = 0xFFFFFF  # White

    bg_sprite = displayio.TileGrid(color_bitmap, pixel_shader=color_palette, x=0, y=0)
    splash.append(bg_sprite)

    # Draw a smaller inner rectangle
    inner_bitmap = displayio.Bitmap(width - border * 2, height - border * 2, 1)
    inner_palette = displayio.Palette(1)
    inner_palette[0] = 0x000000  # Black
    inner_sprite = displayio.TileGrid(
        inner_bitmap, pixel_shader=inner_palette, x=border, y=border
    )
    splash.append(inner_sprite)

    return display, splash


def text_label(text, y):
    return label.Label(
        terminalio.FONT,
        text=text,
        color=0xFFFFFF,
        x=BORDER * 2 + 4,
        y=BORDER * 2 + 2 + y * (FONT_SIZE + 2),
    )


Y = 0


def try_text_label(generate_text):
    global Y
    try:
        display_label = text_label(generate_text(), Y)
        Y += 1
        return display_label
    except:
        return None


def text_areas():
    global Y, als
    Y = 0

    yield try_text_label(lambda: f"Lux: {als.lux}")

    yield (
        try_text_label(lambda: f"IR: {als.infrared}")
        or try_text_label(lambda: f"Color Temp: {als.color_temperature}")
        or try_text_label(lambda: f"White: {als.white}")
        or try_text_label(lambda: f"Proximity: {als.proximity}")
    )
    yield (
        try_text_label(lambda: f"Broadband: {als.broadband}")
        or try_text_label(lambda: f"Color: {hex(als.color)}")
        or try_text_label(lambda: f"Light: {als.light}")
        or try_text_label(lambda: f"Proximity: {als.proximity}")
    )
    yield try_text_label(lambda: f"Polling: {POLLING_TIME}s")


def respond_to_serial_commands():
    global POLLING_TIME, LAST_KEEP_ALIVE_TIME
    if not supervisor.runtime.serial_bytes_available:
        return

    serial_input = input()
    for cmd in serial_input.strip().split("\n"):
        if cmd == "K":
            LAST_KEEP_ALIVE_TIME = time.monotonic()
        elif cmd[0] == "T":
            if len(cmd) <= 1:
                continue

            try:
                cmd_time = int(cmd[1:])
            except:
                pass
            else:
                POLLING_TIME = float(cmd_time) / 1000
                refresh_display()


def refresh_display():
    global oledio, oled, OLED_TEXT_AREAS
    if oledio:
        for i, t in enumerate(text_areas()):
            if t:
                oledio[i - OLED_TEXT_AREAS] = t
        oled.refresh()


POLLING_TIME = 0.5
POLLING_INTERVAL = 0.5
MAX_NO_KEEP_ALIVE_SECONDS = 60
LAST_KEEP_ALIVE_TIME = time.monotonic()

als = lux_sensor(i2c)
try:
    oled, oledio = oled_display(i2c, WIDTH, HEIGHT, BORDER)
except Exception as exc:
    print(exc)
    oled, oledio = None, None


OLED_TEXT_AREAS = 0
if oledio:
    for text_area in text_areas():
        if text_area:
            oledio.append(text_area)
            OLED_TEXT_AREAS += 1


while True:
    steps = int(round(POLLING_TIME / POLLING_INTERVAL))
    for step in range(steps):
        respond_to_serial_commands()
        seconds_since_last_keep_alive = time.monotonic() - LAST_KEEP_ALIVE_TIME
        if seconds_since_last_keep_alive > MAX_NO_KEEP_ALIVE_SECONDS:
            print(
                f"{seconds_since_last_keep_alive} seconds passed since last keep alive. Resetting..."
            )
            supervisor.reload()
        time.sleep(POLLING_INTERVAL)

    lux = als.lux

    if lux is not None:
        print(f"{lux} lux")

    refresh_display()
