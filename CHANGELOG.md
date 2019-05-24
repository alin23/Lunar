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
