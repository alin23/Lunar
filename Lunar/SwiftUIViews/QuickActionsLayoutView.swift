import Defaults
import SwiftUI

struct QuickActionsLayoutView: View {
    @ObservedObject var dc: DisplayController = DC

    @Default(.showSliderValues) var showSliderValues
    @Default(.mergeBrightnessContrast) var mergeBrightnessContrast
    @Default(.showVolumeSlider) var showVolumeSlider
    @Default(.showRawValues) var showRawValues
    @Default(.showNitsText) var showNitsText
    @Default(.showNitsOSD) var showNitsOSD
    @Default(.showBrightnessMenuBar) var showBrightnessMenuBar
    @Default(.showOnlyExternalBrightnessMenuBar) var showOnlyExternalBrightnessMenuBar
    @Default(.showOrientationInQuickActions) var showOrientationInQuickActions
    @Default(.showOrientationForBuiltinInQuickActions) var showOrientationForBuiltinInQuickActions
    @Default(.showInputInQuickActions) var showInputInQuickActions
    @Default(.showPowerInQuickActions) var showPowerInQuickActions
    @Default(.showStandardPresets) var showStandardPresets
    @Default(.showCustomPresets) var showCustomPresets
    @Default(.hidePresetsOnSingleDisplay) var hidePresetsOnSingleDisplay
    @Default(.showXDRSelector) var showXDRSelector
    @Default(.showHeaderOnHover) var showHeaderOnHover
    @Default(.showFooterOnHover) var showFooterOnHover
    @Default(.keepOptionsMenu) var keepOptionsMenu

    @Default(.alternateMenuBarIcon) var alternateMenuBarIcon
    @Default(.hideMenuBarIcon) var hideMenuBarIcon
    @Default(.showDockIcon) var showDockIcon
    @Default(.moreGraphData) var moreGraphData
    @Default(.infoMenuShown) var infoMenuShown
    @Default(.adaptiveBrightnessMode) var adaptiveBrightnessMode
    @Default(.dimNonEssentialUI) var dimNonEssentialUI

    var body: some View {
        ZStack {
            Color.clear.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Group {
                    Group {
                        SettingsHeader(text: "Visibility")

                        SettingsToggle(text: "Only show top buttons on hover", setting: $showHeaderOnHover.animation(.fastSpring))
                        SettingsToggle(text: "Only show bottom buttons on hover", setting: $showFooterOnHover.animation(.fastSpring))
                        SettingsToggle(text: "Dim non-essential UI elements", setting: $dimNonEssentialUI.animation(.timingCurve(0.68, -0.55, 0.265, 1.55, duration: 0.8)))
                        SettingsToggle(text: "Save open-state for this menu", setting: $keepOptionsMenu.animation(.fastSpring))
                    }
                    Divider().padding(.vertical, 2).opacity(0.6)
                    Group {
                        SettingsHeader(text: "Controls")
                        SettingsToggle(text: "Show slider values", setting: $showSliderValues.animation(.fastSpring))
                        SettingsToggle(text: "Show power button", setting: $showPowerInQuickActions.animation(.fastSpring))
                        if dc.activeDisplayList.contains(where: \.hasDDC) {
                            SettingsToggle(text: "Show volume slider", setting: $showVolumeSlider.animation(.fastSpring))
                            SettingsToggle(text: "Show input source selector", setting: $showInputInQuickActions.animation(.fastSpring))
                        }
                        SettingsToggle(text: "Show rotation selector", setting: $showOrientationInQuickActions.animation(.fastSpring))
                        SettingsToggle(text: "Show rotation for built-in screen", setting: $showOrientationForBuiltinInQuickActions.animation(.fastSpring))
                            .padding(.leading)
                            .disabled(!showOrientationInQuickActions)
                        if dc.activeDisplayList.contains(where: \.supportsEnhance) {
                            SettingsToggle(text: "Show XDR Brightness buttons", setting: $showXDRSelector.animation(.fastSpring))
                        }
                        if dc.activeDisplayList.contains(where: \.hasDDC) {
                            SettingsToggle(text: "Merge brightness and contrast", setting: $mergeBrightnessContrast.animation(.fastSpring))
                        }
                    }
                    Divider().padding(.vertical, 2).opacity(0.6)
                    Group {
                        SettingsHeader(text: "Presets")
                        SettingsToggle(text: "Show standard presets", setting: $showStandardPresets.animation(.fastSpring))
                        SettingsToggle(text: "Show custom presets", setting: $showCustomPresets.animation(.fastSpring))
                        SettingsToggle(text: "Hide presets when there's only one screen", setting: $hidePresetsOnSingleDisplay.animation(.fastSpring))
                    }
                }
                Divider().padding(.vertical, 2).opacity(0.6)
                Group {
                    SettingsHeader(text: "Info")
                    #if arch(arm64)
                        if dc.activeDisplayList.contains(where: \.noDDCOrMergedBrightnessContrast) {
                            SettingsToggle(text: "Show nits limits when hovering on the slider", setting: $showNitsText.animation(.fastSpring))
                        }
                        SettingsToggle(text: "Show nits value in the brightness OSD", setting: $showNitsOSD)
                    #endif
                    if adaptiveBrightnessMode.hasUsefulInfo {
                        SettingsToggle(text: "Show useful adaptive info near mode selector", setting: $infoMenuShown.animation(.fastSpring))
                    }
                    if dc.activeDisplayList.contains(where: \.hasDDC) {
                        SettingsToggle(text: "Show last raw values sent to the display", setting: $showRawValues.animation(.fastSpring))
                    }
                    SettingsToggle(text: "Show brightness near menubar icon", setting: $showBrightnessMenuBar.animation(.fastSpring))
                    SettingsToggle(
                        text: "Show only external monitor brightness",
                        setting: $showOnlyExternalBrightnessMenuBar.animation(.fastSpring)
                    )
                    .padding(.leading)
                    .disabled(!showBrightnessMenuBar)
                }
                Divider().padding(.vertical, 2).opacity(0.6)
                Group {
                    SettingsToggle(text: "Hide menubar icon", setting: $hideMenuBarIcon)
                    SettingsToggle(text: "Alternate menubar icon", setting: $alternateMenuBarIcon)
                    SettingsToggle(text: "Show dock icon", setting: $showDockIcon)
                    SettingsToggle(
                        text: "Show more graph data",
                        setting: $moreGraphData,
                        help: "Renders values and data lines on the bottom graph of the Display Settings window"
                    )
                }
                Spacer()
                Color.clear
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
