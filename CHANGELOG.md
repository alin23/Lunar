# 5.0.0
## Features

* Support for **M1 Pro** and **M1 Max**
* **Onboarding** process on first launch
* Redesigned **Diagnostics**

![diagnostics screen](https://files.lunar.fyi/onboarding-diagnostics.png)

* Redesigned **Quick Actions** menu
    * The menu appears on click instead of hover over the menu bar icon now
    * The native menu can be shown using:
        * Right click (or two finger Trackpad click) on the menu bar icon
        * Click on the three dots icon in the top right of the Quick Actions menu

![quick actions menu](https://files.lunar.fyi/quick-actions.png)

* **Sliders everywhere**
    * Merged **brightness and contrast slider**
    * Volume slider in the QuickActions menu
    * *Only possible with the incredible help of [@waydabber](https://github.com/waydabber), maker of [BetterDummy](https://github.com/waydabber/BetterDummy)*
* Redesigned **Display Settings** menus

![new display settings icons](https://files.lunar.fyi/display-settings-icons.png)

* **Restart Lunar** menu item and hotkey

![restart hotkey](https://files.lunar.fyi/restart-hotkey.png)

* **Overlay/Gamma switcher** button inside the Controls menu

![overlay button](https://files.lunar.fyi/overlay-button.png)

* **App presets** now work for the built-in display as well

![builtin app preset](https://files.lunar.fyi/builtin-app-preset.png)

* Adding **Option** key to the **BlackOut** hotkey will turn off monitor completely through DDC
    * Example: let's say you have configured BlackOut to activate on `Ctrl`-`Command`-`6`
    * Then pressing `Ctrl`-`Command`-`Option`-`6` will allow you to turn off the monitor completely (*just like pressing its physical power button*) if the monitor supports that function
* **Rounded corners** for any display

<video autoplay loop muted width="572" height="450" src="/static/video/screen-corner-radius.mp4" style="width: 572px; height: 450px"/>


## Improvements

* Enable the power button in the Lunar window to also work when the **Allow BlackOut on single screen** option is enabled
* Add *high memory usage checker* to aid in fixing memory errors in the future
* Use *Apple Native smooth transitions* using private macOS APIs on Apple vendored displays
* Smooth transitions can now happen in parallel if there are multiple displays with different controls
* Cut the memory usage in half by replacing large images in the UI with vector-drawn bezier paths
* Improved BlackOut logic when using a dummy display
* Filter checkbox for showing/hiding dummy displays
* Hotkeys changing the display with the cursor now affect all monitors in a mirror set
    * This improves support for apps like [BetterDummy](https://github.com/waydabber/BetterDummy)

## Fixes

* Software overlay for Sidecar now appears correctly on first connection
* Notify the system when changing built-in brightness to allow the system curve to readapt

# 4.9.7
## Features

* **Onboarding**
* **Restart Lunar** menu item and hotkey

![restart hotkey](https://files.lunar.fyi/restart-hotkey.png)

* **Volume slider**
* **Overlay/Gamma switcher** button inside the Display Settings menu
* Adding **Option** key to the **BlackOut** hotkey will turn off monitor completely through DDC
    * Example: let's say you have configured BlackOut to activate on `Ctrl`-`Command`-`6`
    * Then pressing `Ctrl`-`Command`-`Option`-`6` will allow you to turn off the monitor completely (*just like pressing its physical power button*) if the monitor supports that function

## Improvements

* Enable the power button in the Lunar window to also work when the **Allow BlackOut on single screen** option is enabled 
* Add high memory usage checker to aid in fixing memory errors in the future
* Smooth transitions can now happen in parallel if there are multiple displays with different controls
* Cut the memory usage in half by replacing large images in the UI with vector-drawn bezier paths

## Fixes

* Software overlay for Sidecar now appears correctly on first connection

*And a little easter egg:*

![easter egg](https://files.lunar.fyi/display-rounded-corners.png)
# 4.9.6
## Features

* **Useful Info** menu item in menu bar that can also be hidden
* **Allow BlackOut on single screen** advanced setting for people that:
    * mostly use BlackOut from the keyboard 
    * have the need to turn off the external monitor while the MacBook is in clamshell mode
* Option to show brightness and contrast of the active display beside the menu bar icon
* Option to hide the orientation switcher in the QuickActions menu
* Hide QuickActions when clicking anywhere outside of it

![menu bar improvements](https://static.lunar.fyi/img/menu-bar-improvements/menu-bar-improvements.png)

## Improvements

* Change **Apply Gamma** checkbox to an enable/disable button that also disables value editing
* Close Quick Actions menu faster when moving the cursor away from it
* Better *possible clamshell mode detection* to avoid setting external monitor brightness to 0 when closing the MacBook lid

## Fixes

* Fix crashes that happened because of accessing AVService/I2C cache from multiple threads
* Make sure to update some text fields that were not updated on launch
# 4.9.5
## Features

* **Clock Mode**: schedule brightness and contrast presets based on sunset/sunrise/noon or a specific time
* **Dark Overlay** dimming for displays that don't support Gamma or DDC (**DisplayLink** and **Sidecar** usually)
* **Curve Learning** now works with external brightness changes if **Refresh values from monitor settings** is enabled in [Advanced settings](lunar://advanced)
    * Contrast does nothing when the overlay is used
* Sensor Mode can now use the internal light sensor of the M1 MacBooks
* Add option to disable checking for DDC responsiveness in [Advanced settings](lunar://advanced)
* Display filters for deciding what to show in the Preferences window:
    * Virtual displays
    * AirPlay displays
    * Projectors
    * Disconnected monitors

## Improvements

* Improve dynamic gain on the TSL2591 external light sensor by checking for overflows
    * You will need to reinstall the ambient light sensor firmware to get this improvement 
* Improve Gamma smooth transitions by removing unnecessary animations and allowing it to appear on Mission Control
    * Thanks to [@waydabber](https://github.com/waydabber) for finding out this edge case and for suggesting that the window needs to be set as `stationary` to fix it
* Recover Facelight state after screen sleep/wake
* Improve smooth and slow transitions for Apple vendored displays that can use Native Controls
* Reset audio device cache on wake and on display reconnection to avoid volume controls not working in some cases
* Do network requests asynchronously where possible to improve responsiveness and fix some memory leaks
* Simplify menu bar icon menu

## Fixes

* Fix crash when the DDC faults storage was accessed from multiple threads
* Fix crash that happened on modifying the I2C controller cache when the IO registry tree changed
# 4.9.1
## Fixes

* Fix crash because of gamma smooth transition logic
* Fix crash when Sensor Mode would update brightness on a non-main thread
* Avoid app entering a not responding state when in Location mode and waking the screen

## Improvements

* Make sure Gamma never goes below `0.08` on brightness 0 to retain visibility
* Allow **press-and-hold** detection to be disabled for users that encounter problems with it
* Remove unused serial-port and volume-based sensor options

# 4.9.0
## Features

* Revamped Hotkeys page for easier configuration of how the keys should work
* Hotkeys now support press and hold for repeating actions
* Add configurable FaceLight brightness/contrast settings inside the [Lunar Display settings](lunar://display/settings)
* Add **Disable all hotkeys** button on the Hotkey page
    * ![disable all hotkeys button](https://lunar.fyi/static/img/disable-all-hotkeys-button/disable-all-hotkeys-button.png)
* Add **Slow** brightness transition option
* Change Lunar window pages using keys:
    * Press **H** for the *Hotkeys* page
    * Press **C** for the *Configuration* page
    * Press **B** for the *Built-in display* page
    * Press **1..9** for switching to the *Display* page with that number

<video src="https://static.lunar.fyi/page-key-demo.mp4" autobuffer autoloop loop muted autoplay></video>

## Improvements

* Re-apply BlackOut on screen wake to account for brightness being set to a non-zero value by the system
    * This needs **Re-apply brightness on screen wake** to be enabled inside [Advanced settings](lunar://advanced)
* Make the Gamma smooth transition dot even less visible to avoid creating the perception of a dust speck on the screen

## Fixes

* Fix Lunar not responding in some cases when waking up from sleep
* Fix swipe being blocked on the Configuration page


# 4.8.5
## Fixes

* Fix BlackOut hotkey not reflecting in the menu bar item
* Fix Check for Updates not working on some occasions

## Features

* Add a way to hide the macOS volume OSD for monitors that have their own volume indicator
    * ![screenshot showing Lunar's setting for hiding the macOS Volume OSD](https://lunar.fyi/static/img/volume-osd/volume-osd.png)

# 4.8.4
## Features

* Add navigation bar and remove left/right arrow buttons
* Simplify and smoothen brightness graph
    * More complex data can be shown by enabling **Show more graph data** in [Advanced settings](lunar://advanced)

## Fixes

* Fix internal display being dimmed accidentally after the lid was opened
* Fix QuickActions popover closing accidentally right after opening

## Improvements

* Add **Continue** button for diagnostics instead of relying on pressing keyboard keys
* Improve Native Controls detection for the built-in display when closing/opening the lid

# 4.8.3
## Fixes

* Fix DDC for monitors that act as TVs when in fact they aren't

## Improvements

* Add contact form on lunar.fyi
* Allow fully offline installations

# 4.8.2
## Fixes

* Make Gamma ColorSync profile matching work on Intel as well
    * Many thanks to [@waydabber](https://github.com/waydabber) for suggesting that a Gamma table of `256` values might fix this
* **Fix Hotkeys handling** after adding the built-in display page
* Add missing hotkeys for changing screen orientation in [Advanced settings](lunar://advanced)
* Fix `recursive locking` crash because of using `NSScreen` inside `MPDisplay`

# 4.8.1
## Fixes

* Fix stack overflow crash in detecting if a display is built-in
* Check for display ID to be online before reading Gamma
* Make ColorSync profile matching in Software Control mode M1 only
    * This is because Apple's `CGGetDisplayTransferByTable` is buggy on Intel and crashes the app on some systems

# 4.8.0
## Features

* **Dark Mode UI**
    * ![dark mode UI](https://static.lunar.fyi/dark-mode.png)
* Add **[Built-in Display page](lunar://display/builtin)**
    * ![built-in display page](https://static.lunar.fyi/builtin.png)
* **[BlackOut](https://lunar.fyi/#blackout)**: a feature that lets you selectively turn off displays by:
    * Mirroring the main display contents
    * Setting their brightness and contrast to 0
    * **How to use:**
        * Press `Ctrl+Cmd+6` to activate it and turn off the display where the cursor is
        * You can also activate it by *clicking the power button* on the display page for the following cases:
            * Built-in display
            * External monitors that don't support DDC
    * ![blackout power off button](https://static.lunar.fyi/blackout-button.png)
* Add *"Use Alternate Brightness Keys"* checkbox on the [Hotkeys page](lunar://hotkeys)
    * Useful if you have a keyboard that has `F14`/`F15` keys and the Brightness keys can send special key codes
* Add *"Include Built-in Display"* checkbox on the [Hotkeys page](lunar://hotkeys)
    * Useful if you use a Hackintosh with an external monitor set as a built-in display
* Add **Lock Curve** button for disabling the auto-learning curve algorithm when needed
* Add **Reset** buttons in the [gear icon menu](lunar://display/settings)
* Allow setting **minimum** values for **DDC Limits**
* Add more useful controls in the [gear icon menu](lunar://display/settings)
    * **DDC Color Gain**
    * **Resolutions** (including hidden resolutions)
    * **Screen orientation**
    * ![gear icon menu new controls](https://static.lunar.fyi/gear-menu-resolution-rotation.png)
    * ![resolutions dropdown](https://static.lunar.fyi/resolutions.png)
* Replace the Adaptive button with a more useful **input switch dropdown** in the QuickActions menu
    * ![quick actions menu with input and screen orientation](https://static.lunar.fyi/quick-input-rotation.png)

## Improvements

* **Respect custom color profiles when adjusting brightness using Gamma**
* Handle non-english locales in text fields
* Show error when CLI can't be installed and show a possible fix using chown and chmod
* Allow fuzzy display name matching in CLI
    * Things like this should work now:
        * Switch input to HDMI for LG UltraFine: `lunar displays ultrafine input hdmi`
        * Read contrast of Dell U3419W: `lunar displays dell34 contrast`
* Switch to rounding the curve value in the auto-learning algorithm for more precise mappings
* Make transitions smoother on Apple displays

## Fixes

* Fix crash on Monterey beta 5 because of `Thread.private` not existing anymore
* Handle cases where app exceptions can't be added because their bundle doesn't contain `CFBundleName`
* Pin `TSL2591` library to a known working version
* Fix DDC limits not being applied correctly in Manual Mode
* Fix data race crash when iterating some dictionaries
* Allow brightness 0 in Sync Mode on iMacs 

# 4.7.2
## Improvements

* Add SPI as lib dependency for sensor firmware to avoid compilation errors in the future
* Improve Network Control monitor matching in multi-monitor cases
* Quit older instances if a user launches Lunar while it is already running
* Always show Network Control prompt on the main monitor
* Check if new value is different from old value when listening for settings changes to avoid duplicating events

## Fixes

* Don't check for updates on launch to avoid annoying people who don't like updates as much as I do
* Fix typo which caused the monitor serial to be wrongly compared to the product ID when matching monitors
* Allow CLI to set properties that don't need an available control

# 4.7.1
## Improvements

* Remove the need for a yellow dot in Gamma and Network control
* Add **Show virtual displays** checkbox in [Advanced settings](lunar://advanced)
    * Turns out DisplayLink monitors show up as virtual and you need this checked if you want Lunar to see the monitor 
* Fix Gamma **(Software Controls)** curve calculation being skewed in the 0% to 10% range
    * The zero point (no gamma changes) is now when BRIGHTNESS=100 and CONTRAST=75
    * Lightness change between brightness values should be more consistent with the human eye response to light

## Fixes

* Don't check for updates on launch if **Check for updates automatically** is disabled in [Advanced settings](lunar://advanced)
* Fix some unexpected crashes
* Fix license being disabled erroneously on network problems

# 4.7.0
# Features

* Add support for ESP8266 sensor boards
* Implement auto-gain and adaptive integration time for light sensors

# Improvements

* Make firmware installer window appear faster by looking for serial devices in the background
* Highlight **Advanced** settings button
* Add URL for opening the gear icon menu directly: [lunar://display/settings](lunar://display/settings)

# Fixes

* Fix support for Adafruit Metro ESP32 S2
* Fix some unexpected crashes
* Keep Lunar Pro active when license fails verification with Paddle for the first few times

# 4.6.5
## Features

* `lunar://` URLs for easy access to specific parts of the UI
    * Settings page: `lunar://settings`
    * Advanced Settings page: `lunar://advanced`
    * Hotkey page: `lunar://hotkeys`
    * Display page: `lunar://displays`
    * Specific display page: `lunar://displays/:number` (e.g. `lunar://displays/3` for third display)

## Fixes

* Fix Auto-learning for Location mode when the sun is below the horizon (negative degrees)
* Fix silent automatic updates

## Improvements

* Make the main window interaction smoother by removing unnecessary chart rendering
* Make the paid updates message clearer when the free updates period expires
# 4.6.3
## Fixes

* Fix [Auto-learning Curve](https://lunar.fyi/#curve) for **Location** and **Sensor** mode
* Move some UI operations on the main thread to keep the window visually consistent
* Check for possible clamshell mode while Sync Mode is adapting to avoid setting brightness to 0 before the `IsLidClosed` flag has been set

# 4.6.2
## Features

* **Tutorial completed for DIY Wireless Ambient Light Sensor:** [https://lunar.fyi/sensor](https://lunar.fyi/sensor)
* Add option to apply volume 0 on pressing mute in **Advanced** settings
    * Some monitors don't accept the mute DDC control so this could be useful
* Curve factors separated by display and mode
    * The curve factors are now found in the gear icon menu and are stored on a per-monitor and per-mode basis
    * If you set some curve factors while Lunar is in Sync Mode and then change to Location Mode for example, there will be different curve factor values
    
## Improvements

* Re-apply brightness and contrast when the display control changes

## Fixes

* Correctly turn on/off the refresh values thread when checking/unchecking "Refresh values from monitor settings"
* Turn on Sync Mode correctly on Lunar launch

# 4.6.1
## Features

* Support for DIY Wireless Ambient Light Sensor
    * Tutorial on how to create your own sensor is almost done
    * Please check this page periodically for updates: [https://lunar.fyi/sensor](https://lunar.fyi/sensor)

## Improvements

* Update Paddle framework which fixes the creation of the file `default.profraw` on every run of the CLI
* Show current version under the Lunar logo in the main window

## Fixes

* Fix crashes because of thread unsafe hotkeys cache
* Fix crash because of accessing a nil variable
* Fix brightness being set to max after sleep
* Fix hotkey not being unregistered when clearing it using the `x` button

# 4.5.5
## Improvements

* Allow up to 3 input hotkeys per monitor
* Improve AVService detection to allow even more monitors to be controlled through DDC on M1 Macs
* Add configurable DDC Sleep Factor in Advanced Settings

## Fixes

* Fix crashes because of thread unsafe settings cache
* Remove scrolling from Quick Actions popover to fix all the disappearing issues
* Fix name being set to "Unknown" in some cases
* Fix "License Verification failed after 5 days" appearing incorrectly
* Fix input hotkeys not working anymore after a while
* Fix input dropdown not being updated with latest selected input by hotkey
# 4.5.3
## Improvements

* Disable Gamma by default in Hardware/Native/Network controls
* Add checkbox to enable Gamma in non-Software controls
* Improve Mac Mini HDMI port detection to allow USB-C-to-HDMI adapters to work with DDC on the USB-C port

## Fixes

* Fix Boolean value handling in the CLI integration
* Fix Quick Actions popover contents disappearing on some occasions
# 4.5.1
## Features

* **DDC support for M1 Macs** (beta)
    * Only possible because of the great advice and example code from [Zhuowei Zhang](https://github.com/zhuowei) and the amazing work of [Davide Guerri](https://github.com/dguerri) and [Tao J](https://github.com/tao-j)
    * **Mac Mini HDMI still not working**: [Mac Mini Github issue](https://github.com/alin23/Lunar/issues/125)
+ Add a way to set default gamma values when using Hardware/Native/Network controls

## Improvements

* Add "Hide yellow dot" checkbox in Advanced settings
* Reset DDC write/read faults when a successful read is detected to avoid the incorrect marking of monitors as *Non-reponsive DDC*

## Fixes

* Fix license not being activated without an app restart
* Fix Location Mode not fetching correct sunrise/sunset/noon when close to midnight
* Don't reset ColorSync settings and hopefully respect calibration profiles in Gamma mode
* Fix brightness flickering caused by Gamma controls kicking in faster than DDC/CoreDisplay/Network by adding a 5 second delay to the Gamma setter after:
    * App launch
    * System startup
    * Login 
    * Wake from standby
    * Display connection/reconnection

# 4.3.0
## Features
* Allow negative offsets for app exceptions
* Add separate curve factors for brightness and contrast

## Improvements

* Add a way to change the automatic check for updates interval in Advanced settings
* Isolate reset actions into a dropdown
* App exceptions logic rewrite
    * Now the offsets are only applied if the app has any visible window on an external monitor (in the past the offsets were applied on app launch/quit)
    * The offsets are also only applied to the monitor where the app is visible

## Fixes

* Always reset adjustment limit within 24 hours
* Fix diagnostics message saying the monitor supports DDC when in fact it didn't support it

# 4.2.3
## Fixes

* Shake window when trying to input an invalid field value
* Revert all changes to a field when pressing escape
* Pressing tab inside a field will commit the value
* Show Lunar window on the screen where the cursor is
* Hide yellow dot on operation end
# 4.2.2
## Fixes

* Make sure brightness/contrast is not changed automatically when it is marked as locked
* Make gamma operation highlighter async to avoid blocking the UI on rare occasions

# 4.2.1
## Fixes

* Fix flicker because of switching to/from fullscreen apps
* Fix app not responding on startup because of blocking the main thread too early in the startup process

# 4.2.0
## Fixes

* Fix curve factor going to `0.00` on some systems

## Improvements

* Improve DDC framebuffer detection logic by using the private `CGSServiceForDisplayNumber` API
* Add a way to enable verbose logging in Advanced settings
* Set DDC back to responsive if any read/write succeeds

# 4.1.4
## Fixes

* Fix changing modes would not stop/start the Sync/Location/Sensor listeners

## Improvements

* Show why Sync/Location/Sensor modes are disabled when Lunar Pro is not active 
* Add **Join the community** menu item

# 4.1.3
## Improvements

* Use DisplayServices to read builtin brightness and fix the HDR issue

## Fixes

* Show correct builtin brightness in Lunar menu

# 4.1.2
## Fixes

* Fix built-in display detection logic
* Fix media key handler

# 4.1.1
## Fixes

* Fix crash because of launch at login empty list

# 4.1.0
## Features

* Make it possible to set Pro Display XDR and LG UltraFine monitors as source for Sync Mode

## Improvements

* Show tooltips with the reason why a specific Mode is disabled when hovering on it
* Allow controlling monitor with the cursor on it when **Send Keys To All Monitors** is unchecked
* Add useful reset buttons in the gear icon menu
    * **Reset Network Control** for when the network controls aren't activated automatically because the system mDNS browser is stuck
    * **Reset DDC** for when DDC is deemed unresponsive because the system has reported the monitor as active when it was in fact inactive

## Fixes

* Fix crashes because of gamma locking
* More UI accesses moved to Main Thread
* Fix display name edit not saving
* Fix network controller reset on wake and display reconnect
* Fix QuickActions floating window disappearing too quickly
# 4.0.5
## Improvements

* Add native support for old **Apple Cinema** and **Cinema HD** displays
* Add *Show Dock Icon* option under Advanced settings

## Fixes

* Ensure window is shown when launching Lunar while menubar icon is hidden
* Fix crash on NetServiceBrowser reset
* Fix crash because of settings observer being deallocated too soon

# 4.0.4
## Fixes

* Stop showing **Your period of free updates has expired** when the period of updates is still valid

# 4.0.3
## Fixes

* It seems Lunar needs macOS 10.15 or higher (even though Xcode compiles it just fine for 10.13) so I made that the minimum requirement

## Improvements

* Added *Advanced* setting for disabling brightness re-apply on screen wake
* Show Lunar window before showing Paddle licensing UI
# 4.0.2
## Fixes

* Fix valid updates checking logic
* Show window when menu bar icon is hidden and app is launched while already running
* Fix data race when ddcutil service is found on the network
* Fix setting brightness for Apple vendored displays
* Delay reset for mDNS browser when coming out of standby to avoid a recent CoreFoundation bug: [CFRunLoopSource type mismatch, found CFSocket](https://developer.apple.com/forums/thread/663772)
* Check for Catalina or higher before trying to get display info dictionary

## Improvements

* Added Sync Mode test inside diagnostics
# 4.0.1
## Fixes

* Show window when menu bar icon is hidden and app is launched while already running
* Fix data race when ddcutil service is found on the network
* Fix setting brightness for Apple vendored displays
* Delay reset for mDNS browser when coming out of standby to avoid a recent CoreFoundation bug: [CFRunLoopSource type mismatch, found CFSocket](https://developer.apple.com/forums/thread/663772)
* Check for Catalina or higher before trying to get display info dictionary

## Improvements

* Added Sync Mode test inside diagnostics
# 4.0.0
## Features

**Lunar 4 is released!**

Head over to [the official website](https://lunar.fyi) for more details.
# 3.2.3
## Improvements

- Show built-in brightness in menu
- Update hotkey libraries
- Use Swift Package Manager for most of the frameworks
- Use LaunchAtLogin framework to fix start at login
# 3.2.2
## Fixes

- Fix tooltip not closing when clicking on the display page

## Improvements

- Detect scrolling direction so that scrolling up always increases value
# 3.2.1
## Improvements

- Make display name editable

# 3.2.0
## Fixes

- Fix monitor volume restore
- Fix crashes because of using deallocated self

# 3.1.5
## Features

- Implement built-in brightness clipping limits for monitors with lower range of brightness/contrast
- Add a menu item to allow disabling volume key listener

## Fixes

- Fix Location Permissions prompt not showing up on macOS Catalina

## Improvements

- Add a bit more analytics data and route the requests through my own server
- Upload diagnostics to my own server instead of transfer.sh
- Reduce memory usage by manually deallocating unused views

# 3.1.4
## Fixes

- Hide buttons and labels properly when no display is connected
- Fix a ton of memory leaks
- Fix volume keys not being able to be disabled

## Improvements

- Show Lunar version in the menu
- Hide rarely used menu items under an **Advanced** submenu item
# 3.1.3
## Fixes

- Fix Sync mode thread not running on some occasions

## Improvements

- Disable Adaptive button in Manual mode
# 3.1.2
## Fixes

- Fix crash when there are displays with same UUID
- Fix crash on MediaKeyTap deinit

## Improvements

- Add a way to extend brightness range up to 255 for monitors that support this
# 3.1.1
## Fixes

- Fix some memory corruption bugs by improving concurrency
- Properly hide/show the `Non-responsive DDC` message
- Fix diagnostics encryption key missing

## Improvements

- Add _reset on click_ action to the `Non-responsive DDC` message

# 3.1.0
## Fixes

- Make active screen detection more reliable
- Only allow one thread at a time to use DDC to avoid race conditions
- Disable up/down value change hotkeys when Quick Actions disappear
- Embed all used Swift libraries to avoid crashes on some systems

## Improvements

- Increase brightness/contrast/volume hotkey step to 6
- Allow fine-adjustment hotkeys:
    + Use Option + hotkey for hotkeys assigned from the Lunar hotkey page
    + Use Option + Shift + hotkey for media keys
- Open System Preferences for displays/sound when pressing Option + media key
# 3.0.0
## Features
- Add support for changing monitor volume and mute state
- Show native OSD when changing monitor brightness, contrast and volume
- Implement listeners for media keys
    * Lunar will ask for accessibility permissions to enable this functionality
    * Instructions: 
        * Press keyboard brightness keys while the cursor is on an external monitor to change the brightness on that monitor 
        * Press Control + keyboard brightness keys to adjust contrast 
        * Press keyboard volume/mute keys while the audio output is set to the monitor audio device to adjust volume/mute
        * In multi-monitor setups, Lunar can't detect which monitor audio device is selected so it will change the volume of the display that the cursor is on
- Many thanks to Hongfeng Xu (@Mic238) for helping me with extensive testing on these features!


## Improvements

- Detect non-responsive monitors and show that in the Quick Actions popover
- Automatic detection of GPU for adaptive DDC reply delay
    - This should minimize kernel panics and system freezes when reading values from the monitor
- Add special brightness implementation for **LED Cinema** monitors 

## Fixes
- Fixed a typo that was preventing smooth transition to be disabled for contrast
# 2.9.9
## Fixes

- Minimize non-null assertions
- Fix Day Length calculation in Location mode
- Fix "end scrolling" detection

# 2.9.8
## Features

- Add option to remove disconnected displays from the Quick Actions popover
- Better detection of builtin displays

## Fixes

- Fix a memory corruption bug

## Improvements

- Improve detection of slow DDC implementations
# 2.9.7
## Features

- Add special support for Apple Thunderbolt Display
- Add option to manually enable brightness monitoring (only for the brave)

## Fixes

- Filter out built-in and testing displays from saved data

## Improvements

- Make an attempt to detect slow DDC implementations and skip reading in those cases
# 2.9.6
## Features

- Show both connected and disconnected displays in Quick Actions

## Fixes

- Fix all kinds of crashes

## Improvements

- Move display and app exceptions from Core Data to User Defaults to avoid concurrency bugs
# 2.9.5
## Features

- Add option to disable Quick Actions popover

# 2.9.4
## Fixes

- Fix lid closed detection on iMacs and Mac Minis

## Improvements

- Add more crash data to allow me to better diagnose issues remotely
- Make transitions smooth by default on UltraFine displays
- Read brightness periodically by default on UltraFine displays
# 2.9.3
## Fixes

- Fix system freeze caused by trying to read monitor brightness using DDC
- Fix Manual mode values not respecting limits

## Improvements

- Show Quick Actions when changing brightness/contrast using hotkeys
# 2.9.10
## Improvements

- Clamshell mode detection toggle in menu

# 2.9.1
## Features
- Quick Actions popover when hovering over the menu item
- Add support for LG UltraFine displays
- Implement Clamshell Mode
- Keep Lunar in sync by reading the monitor's brightness and contrast periodically
- Remove all third party analytics and add a single request for counting unique users anonymously
    - This request sends a SHA256 hash of your device serial number to my server through a pubsub service
    - The serial number is impossible to deduce from the hash and the request is untraceable back to your device

## Fixes

- Fix left and right hotkeys not being registered sometimes
- Patch Magnet to disable Input Monitoring request
- Fix preferences saving permission
- Fix dictionary access race condition in DDC code

## Improvements

- Replace Fabric with Sentry for crash reporting because Fabric was acquired by Google
- Remove HotKey library and rely only on the Magnet framework
- Add sane defaults for brightness/contrast limits and offsets
- Improve speed and responsiveness by using concurrent tasks where possible
# 2.9.0
## Features

- Lunar is now notarized and signed with a certificate bought from your donations! Thanks everyone!
- Added a polling interval in the Sync mode to adjust how fast Lunar syncs the built-in display brightness

## Fixes

- Fix `Start at Login` functionality
- The available settings now change instantly when you change the mode
- Settings should save properly now
- Fix a few crashes in the C code for DDC (still a few to go, but new job, less time..)

## Improvements

- Change help popovers font to something more legible
- Make help links clickable (somewhat)
# 2.8.3
## Fixes

- Fix data store merge policy

## Improvements

- Add help buttons with popovers for explaining settings and modes

# 2.8.2
## Fixes

- Fix memory management of EDID data

# 2.8.1
## Fixes

- Fix another case where UUID can't be allocated
- Fix display name detection
- Allow new monitor data to overwrite cached db rows

# 2.8.0
## Features

- Make the UI larger to allow for more info and settings
- Add more annotations on the brightness chart

## Fixes

- Fix cases where the UUID can't be allocated
# 2.6.0
## Features

- Add customizable location coordinates
- Move updates to new domain: [lunar.fyi](https://lunar.fyi)
# 2.5.0
## Fixes

- Revert DDC to C implementation with added multi-monitor support
- Fix 2.4.0 regression where only some types of connectors worked
# 2.4.0
## Features

- Add diagnostic tools
    - You can now open Lunar menu and click on *Open Lunar diagnostics* to send me Lunar logs
- Complete multi-monitor support

## Fixes

- Use system generated UUID to store settings per display

## Improvements

- Convert to DDC handling code to Swift
- Store min/max settings as soon as they are changed

# 2.3.3
## Fixes

- Use all EDID data to encode monitor IDs
    - this should allow Lunar to support multiple monitors of the same kind

## Improvements

- Convert to Swift 5

# 2.3.2
## Fixes

- Don't send DDC/CI request for locked value

# 2.3.1
## Fixes

- Check chart entries bounds before updating

## Improvements

- Move to edDSA key for signing updates
# 2.3.0
## Fixes

- Use brightness/contrast offsets only in Sync mode

## Features

- Smooth Transition option **<small>[Thanks to Tim Traversy! [@timtraversy](https://github.com/timtraversy) [PR #14](https://github.com/alin23/Lunar/pull/14)]</small>**
    - This makes the brightness/contrast change smoothly from a value to another, instead of jumping directly to that value
    - Check settings page to enable the option
    - I left it off by default because some monitors have a slow response time and smooth transitions end up not being so smooth
- Configurable interpolation factor for Location mode

## Improvements

- Improve charts speed and efficiency with SIMD
- Smoother chart curves

# 2.2.2
## Fixes

- Don't cap brightness/contrast on manual mode

# 2.2.1
## Fixes

- Make the display page white when swiping back from settings
- Reflect hotkey changes on the menu items

## Improvements

- Add button for going to hotkeys page

# 2.2.0
## Fixes

- Make sure user can always swipe to settings page

## Features

- Add page for configuring hotkeys
- Add menu item for toggling "Start at Login"

# 2.1.1
## Fixes

- Remove SwiftyBeaver dependency from LunarService

# 2.1.0
## Features

- Add hotkeys for increasing/decreasing brightness/contrast **<small>[Thanks Hua Duong Tran! [@duongel](https://github.com/duongel) [PR #2](https://github.com/alin23/Lunar/pull/2)]</small>**
- Add individual Lock Buttons for brightness and contrast

## Improvements

- Offsets now work in Location mode too
- Manually adjusting brightness doesn't force Manual mode anymore

## Fixes

- The Adaptive toggle below each monitor now works properly
- App Exceptions were not always working, fixed those cases

# 2.0.3
## Improvements

- Set offset limits to [-100, 90]
- Adjust offsetting formula to get more symmetrical values

# 2.0.2
## Fixes

- Fix a few crashes caused by backing layers and subviews not being available on load

# 2.0.1
## Fixes

- Try not to insert nils in the database

# 2.0.0
## Features

- Sync mode
- The external monitor's brightness/contrast will be kept in sync with the brightness/contrast of the built-in display
- The external monitor's brightness/contrast will still be kept within the configured per-monitor limits
- There are new configurable offsets on the settings page to make the synchronization perfect

## Fixes

- Disable adaptive brightness when no monitor is connected to get to zero energy impact
- Fix interpolation formula
- Disable configurable values when Manual mode is on

# 1.1.1
## Fixes

- Make sure Adaptive activity isn't scheduled more than once so that percent hotkeys work as expected
- Fix an error that prevented the settings to persist in the database

# 1.1.0
## Fixes

- Fix stupid mistake that caused the app to crash for all users

# 1.0.7
## Dev

- Add temporary remote logging to help fix some annoying crashes

# 1.0.6
## Fixes

- Cap interpolated values between 0 - 100
- Fallback to generated display names as it is impossible to extract the real name

## Dev

- Add more logging

# 1.0.5
## Fixes

- Fix a crash when monitor serials aren't unique

## Dev

- Add more context to help debugging errors

# 1.0.4
## Fixes

- Fix compatibility with macOS 10.11

# 1.0.3
## Additions

- Donation link

## Fixes

- Try to get rid of crashes when readapting to max brightness change

# 1.0.2
## Improvements

- Use sunrise/sunset instead of civilSunrise/civilSunset

# 1.0.1
## Fixes

- Fixed crash on missing time for sunrise
- Better check cases where Add App button layer isn't initialized
- Make sure brightness/contrast changes contain both old and new values
