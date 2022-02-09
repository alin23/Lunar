# Lunar - control your monitors, even on M1
## [Now with DDC support for M1](https://lunar.fyi/#m1)

### Intelligent adaptive brightness for your external display ###

[![Support Server](https://img.shields.io/discord/591914197219016707.svg?label=Discord&logo=Discord&colorB=7289da&style=for-the-badge)](https://discord.gg/dJPHpWgAhV)



*Note: Lunar changes the actual (physical) brightness and contrast of the monitor.*

*It doesn't use a software overlay.*

## Table of Contents ##
- [Installation methods](#installation-methods)
- [Features](#features)
- [Known to work list](#tested-and-known-to-work-with-the-following-types-of-connections)
- [Troubleshooting](#troubleshooting)
- [Caveats](#caveats)
- [Contributing](#contributing)
- [Building](#building)

## Installation methods ##
- Download PKG from [Official website](https://lunar.fyi)
- Download PKG from the [Releases page](https://github.com/alin23/Lunar/releases)
- `brew install --cask lunar`

## Features ##
- **[Native keyboard control](https://lunar.fyi/#keys)** and hotkeys for setting brightness, volume and contrast that respect the min/max values per monitor
- **[Sensor-based Adaptive Brightness](https://lunar.fyi/#sensor)** (and contrast) based on [an external light sensor](https://lunar.fyi/sensor)
- **[Sync-based Adaptive Brightness](https://lunar.fyi/#sync)** (and contrast) based on the built-in light sensor of the MacBook or iMac
- **[Location-based Adaptive Brightness](https://lunar.fyi/#location)** (and contrast) based on the sunrise/sunset times in your location
- **[App Exception](https://lunar.fyi/#configuration-page)** list if you need more brightness for specific activities (watching movies, design work)
- **[Input switching](#input-hotkeys)** from a convenient dropdown or using up to 3 input-specific hotkeys
- **[Screen orientation](https://lunar.fyi/#display-settings-page)** change from the menu bar or using hotkeys (Ctrl+0/9/8/7 mapped to 0°/90°/180°/270° for the display with the cursor on it)
- **[Hidden resolutions](https://lunar.fyi/#display-settings-page)** accessible from a dropdown in the [Display Settings menu](#display-settings)
- **[BlackOut](https://lunar.fyi/#blackout)**: turn off monitors (or the built-in display) selectively while also keeping important functions:
    - USB-C charging still works
    - Monitor audio keeps playing
    - Monitor USB hub remains available
    - The built-in keyboard and trackpad are still available for use
    - Avoid overheating the MacBook because of using it with the lid closed

It doesn't interfere at all with the native adaptive brightness that macOS implements for the built-in display.

It works well along Night Shift and True Tone (and f.lux if Gamma/Software controls are not used).


## Display Page ##

![Display page](https://static.lunar.fyi/img/display-page/1920_display-page.png)

### Display Settings ###

![Display settings](https://static.lunar.fyi/img/display-settings/1920_display-settings.png)

### Built-in Display Page ###

![Built-in display page](https://static.lunar.fyi/img/builtin-page/1920_builtin-page.png)

### Display Input Hotkeys ###

![Display input hotkeys](https://static.lunar.fyi/img/input-hotkeys/1920_input-hotkeys.png)

## Configuration Page ##

![Configuration page](https://static.lunar.fyi/img/configuration-page/1920_configuration-page.png)

### Advanced Settings ###

![Advanced Settings](https://static.lunar.fyi/img/advanced-settings/1920_advanced-settings.png)

## Hotkeys Page ##

![Hotkeys page](https://static.lunar.fyi/img/hotkeys-page/1920_hotkeys-page.png)


## Tested and known to work with the following types of connections ##
- HDMI (1.0 - 2.1)
- DisplayPort (1.0 - 2.0)
- Thunderbolt 3 (USB Type-C)
- Thunderbolt 2 (mini DisplayPort)
- VGA
- DVI
- Adapters that forward DDC messages properly

## Troubleshooting ##

Check the [FAQ](https://lunar.fyi/faq)

### Contributing ###
I'm pausing contributions for the moment as Lunar has paid features and isn't compilable because of missing parts of the source code *(Pro features code is encrypted)*.

### Building ###
Lunar can't be built from this repo yet as the source code for the paid features is hidden. I will try to post stubs for those paid features to at least make it compilable in an only-free-features form.
