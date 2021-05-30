# Lunar - control your monitors, even on M1
## [Now with M1 support ](https://lunar.fyi/#m1)

### Intelligent adaptive brightness for your external display


*Note: Lunar changes the actual (physical) brightness and contrast of the monitor.*

*It doesn't use a software overlay.*

## Table of Contents
- [Installation methods](#installation-methods)
- [Features](#features)
- [Known to work list](#tested-and-known-to-work-with-the-following-types-of-connections)
- [Troubleshooting](#troubleshooting)
- [Caveats](#caveats)
- [Contributing](#contributing)
- [Building](#building)

## Installation methods
- Download PKG from [Official website](https://lunar.fyi)
- Download PKG from the [Releases page](https://github.com/alin23/Lunar/releases)
- `brew install --cask lunar`

## Display Page

![Display page](https://static.lunar.fyi/img/display-page/display-page.webp)

## Configuration Page

![Configuration page](https://static.lunar.fyi/img/configuration-page/configuration-page.webp)

## Hotkeys Page

![Hotkeys page](https://static.lunar.fyi/img/hotkeys-page/hotkeys-page.webp)


## Features
- [Sensor-based Adaptive Brightness](https://lunar.fyi/#sensor) (and contrast) based on [an external light sensor](https://lunar.fyi/sensor)
- [Sync-based Adaptive Brightness](https://lunar.fyi/#sync) (and contrast) based on the built-in light sensor of the Macbook or iMac
- [Location-based Adaptive Brightness](https://lunar.fyi/#location) (and contrast) based on the sunrise/sunset times in your location
- **App Exception** list if you need more brightness for specific activities (watching movies, design work)
- Individual settings per display
- [Manual controls](https://lunar.fyi/#keys) and hotkeys for setting brightness and contrast that respect the min/max values per monitor

It doesn't interfere at all with the native adaptive brightness that macOS implements for the built-in display.

It works well along Night Shift and True Tone (and f.lux if Gamma/Software controls are not used).

## Tested and known to work with the following types of connections
- HDMI (1.0 - 2.1)
- DisplayPort (1.0 - 2.0)
- Thunderbolt 3 (USB Type-C)
- Thunderbolt 2 (mini DisplayPort)
- VGA
- DVI
- Adapters that forward DDC messages properly

## Troubleshooting

Check the [FAQ](https://lunar.fyi/faq)

## Caveats
- Lunar *usually* doesn't work with monitors connected through USB hubs/docks/adapters **because a lot of them don't forward DDC messages properly**
- Sync mode doesn't work when the Macbook lid is closed because the light sensor is completely covered

### Contributing
I'm pausing contributions for the moment as Lunar has paid features and isn't compilable because of missing parts of the source code.

### Building
Lunar can't be built from this repo yet as the source code for the paid features is hidden. I will try to post stubs for those paid features to at least make it compilable in an only-free-features form.
