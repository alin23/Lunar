<p align="center">
    <a href="https://lunar.fyi/"><img width="128" height="128" src="https://static.lunar.fyi/svg/lunar.svg" style="filter: drop-shadow(0px 2px 4px rgba(80, 50, 6, 0.2));"></a>
  <h1 align="center"><code style="text-shadow: 0px 3px 10px rgba(8, 0, 6, 0.35); font-size: 3rem; font-family: ui-monospace, Menlo, monospace; font-weight: 800; background: transparent; color: #4d3e56; padding: 0.2rem 0.2rem; border-radius: 6px">Lunar</code></h1>
  <h4 align="center" style="padding: 0; margin: 0; font-family: ui-monospace, monospace;">The defacto app for controlling monitors</h4>
  <h6 align="center" style="padding: 0; margin: 0; font-family: ui-monospace, monospace; font-weight: 400;">Adjust brightness, change volume, switch inputs</h6>
</p>

#### macOS app for controlling monitors, [with native support for both Intel and Apple Silicon](https://lunar.fyi/#m1)

## Community

[![Support Server](https://img.shields.io/discord/852182428155904010.svg?label=Discord&logo=Discord&colorB=7289da&style=for-the-badge)](https://discord.gg/dJPHpWgAhV)

## DDC/CI

Lunar changes the hardware brightness of the monitor using the DDC protocol.

It doesn't use a software overlay if the monitor supports DDC/CI.

## Installation methods
- Download [Lunar.dmg](https://lunar.fyi/download/latest) from [lunar.fyi](https://lunar.fyi/)
- Or `brew install --cask lunar`

## Features
- **[Native keyboard control](https://lunar.fyi/#keys)** and hotkeys for setting brightness, volume and contrast that respect the min/max values per monitor
- **[1000-to-1600 nits of brightness](https://lunar.fyi/#xdr)** for supported **XDR** and **HDR** displays
- **[Dim brightness below 0%](https://lunar.fyi/#subzero)** for late-night work
- **[Sensor-based Adaptive Brightness](https://lunar.fyi/#sensor)** (and contrast) based on [an external light sensor](https://lunar.fyi/sensor)
- **[Sync-based Adaptive Brightness](https://lunar.fyi/#sync)** (and contrast) based on **the built-in light sensor of the MacBook or iMac**
- **[Location-based Adaptive Brightness](https://lunar.fyi/#location)** (and contrast) based on the sunrise/sunset times in your location
- **[App Presets](https://lunar.fyi/#configuration-page)** if you need more/less brightness for specific activities (watching movies, design work)
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

It works well along Night Shift and True Tone (and f.lux if Gamma dimming is not used).


## QuickActions Menu

![QuickActions menu](https://files.lunar.fyi/menu-density-demo.png)

## Display Page

![Display page](https://files.lunar.fyi/display-page.png)

### Display Settings

![Display settings](https://files.lunar.fyi/display-settings.png)

### Built-in Display Page

![Built-in display page](https://files.lunar.fyi/builtin-page.png)

### Display Input Hotkeys

![Display input hotkeys](https://files.lunar.fyi/input-hotkeys.png)

## Configuration Page

![Configuration page](https://files.lunar.fyi/configuration-page.png)

### Advanced Settings

![Advanced Settings](https://files.lunar.fyi/advanced-settings.png)

## Hotkeys Page

![Hotkeys page](https://files.lunar.fyi/hotkeys-page.png)


## Tested and known to work with the following types of connections
- HDMI (1.0 - 2.1)
- DisplayPort (1.0 - 2.0)
- Thunderbolt 3 (USB Type-C)
- Thunderbolt 2 (mini DisplayPort)
- VGA
- DVI
- Adapters that forward DDC messages properly

### Contributing
I'm pausing contributions for the moment as Lunar has paid features and isn't compilable because of missing parts of the source code *(Pro features code is encrypted)*.

### Building
Lunar can't be built from this repo yet as the source code for the paid features is hidden. I will try to post stubs for those paid features to at least make it compilable in an only-free-features form.
