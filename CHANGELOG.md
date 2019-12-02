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
