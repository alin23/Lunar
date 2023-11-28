import Defaults
import SwiftUI

struct AdvancedSettingsView: View {
    @ObservedObject var dc: DisplayController = DC

    @Default(.workaroundBuiltinDisplay) var workaroundBuiltinDisplay
    @Default(.ddcSleepLonger) var ddcSleepLonger
    @Default(.clamshellModeDetection) var clamshellModeDetection
    @Default(.enableOrientationHotkeys) var enableOrientationHotkeys
    @Default(.detectResponsiveness) var detectResponsiveness
    @Default(.disableControllerVideo) var disableControllerVideo
    @Default(.allowBlackOutOnSingleScreen) var allowBlackOutOnSingleScreen
    @Default(.reapplyValuesAfterWake) var reapplyValuesAfterWake
    @Default(.clockMode) var clockMode
    @Default(.nonManualMode) var nonManualMode
    @Default(.oldBlackOutMirroring) var oldBlackOutMirroring
    @Default(.newBlackOutDisconnect) var newBlackOutDisconnect

    @Default(.refreshValues) var refreshValues
    @Default(.gammaDisabledCompletely) var gammaDisabledCompletely
    @Default(.waitAfterWakeSeconds) var waitAfterWakeSeconds
    @Default(.delayDDCAfterWake) var delayDDCAfterWake

    @Default(.autoRestartOnFailedDDC) var autoRestartOnFailedDDC
    @Default(.autoRestartOnFailedDDCSooner) var autoRestartOnFailedDDCSooner
    @Default(.sleepInClamshellMode) var sleepInClamshellMode
    @Default(.disableCliffDetection) var disableCliffDetection
    @Default(.keyboardBacklightOffBlackout) var keyboardBacklightOffBlackout

    @State var sensorCheckerEnabled = !Defaults[.sensorHostname].isEmpty

    var body: some View {
        ZStack {
            Color.clear.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading) {
                Group {
                    #if arch(arm64)
                        if #available(macOS 13, *) {
                            SettingsToggle(
                                text: "Disable the Disconnect API in BlackOut", setting: !$newBlackOutDisconnect,
                                help: """
                                \(dc.displayLinkRunning ? "NOTE: Disconnect API is disabled when DisplayLink is running\n\n" : "")BlackOut can use a hidden macOS API to disconnect the display entirely,
                                freeing up GPU resources and allowing for an easy reconnection when needed.

                                If you're having trouble with how this works, you can switch to the old
                                method of mirroring the display to disable it.

                                Note: Press ⌘ Command more than 8 times in a row to force connect all displays.

                                In case the built-in MacBook display doesn't reconnect itself when it should,
                                close the laptop lid and reopen it to bring the display back.

                                For external displays, disconnect and reconnect the cable to fix any issue.
                                """
                            ).disabled(DC.displayLinkRunning)
                        }
                    #endif

                    SettingsToggle(
                        text: "Allow BlackOut on single screen", setting: $allowBlackOutOnSingleScreen,
                        help: "Allows turning off a screen even if it's the only visible screen left"
                    )
                    if Sysctl.isMacBook {
                        SettingsToggle(
                            text: "Turn off keyboard backlight in BlackOut", setting: $keyboardBacklightOffBlackout
                        )
                        SettingsToggle(
                            text: "Force Sleep when the lid is closed", setting: $sleepInClamshellMode,
                            help: """
                            When the MacBook is connected to a monitor that's also charging the Mac,
                            closing the lid will start Clamshell Mode.

                            That system feature keeps the system awake to allow you to use the external
                            monitor with the lid closed.

                            If you don't use that feature, enabling this option will disable Clamshell
                            Mode automatically when the lid is closed.
                            """
                        )
                    }

                    #if !arch(arm64)
                        if #available(macOS 13, *) {
                        } else {
                            SettingsToggle(
                                text: "Switch to the old BlackOut mirroring system", setting: $oldBlackOutMirroring,
                                help: """
                                Some setups will have trouble enabling mirroring with the new macOS 11+ API.

                                You can try enabling this option if BlackOut is not working properly.

                                Note: the old mirroring system can't handle complex mirror sets with dummies and virtual/wireless displays.
                                The best covered cases are "BlackOut built-in display" and "BlackOut only external displays".
                                """
                            )
                        }
                    #endif
                    Divider()

                    SettingsToggle(
                        text: "Use workaround for built-in display", setting: $workaroundBuiltinDisplay,
                        help: """
                        Forward brightness key events to the system instead of
                        changing built-in display brightness from Lunar.

                        This setting might be needed to persist brightness
                        changes better on some specific older devices.

                        Disables the following functions for the built-in display:
                          • Hotkey Step
                          • Auto XDR
                          • Sub-zero Dimming
                        """
                    )
                    if Sysctl.isMacBook {
                        SettingsToggle(
                            text: "Toggle Manual/Sync when the lid is closed/opened",
                            setting: $clamshellModeDetection
                        )
                    }
                    SettingsToggle(
                        text: "Re-apply last brightness on screen wake", setting: $reapplyValuesAfterWake,
                        help: """
                        On each screen wake/reconnection, Lunar will try to
                        re-apply previous brightness and contrast 3 times.

                        Disable this if system appears slow on screen wake.
                        """
                    )
                }
                Divider()
                Group {
                    SettingsToggle(
                        text: "Enable rotation hotkeys",
                        setting: $enableOrientationHotkeys,
                        help: """
                        Pressing the following keys will change the
                        orientation for the display with the cursor on it:

                            Ctrl+0: 0°
                            Ctrl+9: 90°
                            Ctrl+8: 180°
                            Ctrl+7: 270°
                        """
                    )
                    if dc.activeDisplayList.contains(where: \.hasDDC) {
                        SettingsToggle(
                            text: "Wait longer between DDC requests", setting: $ddcSleepLonger,
                            help: """
                            Some monitors have a slower response time on DDC requests.

                            This option might help reduce flicker in those cases.
                            """
                        )
                        SettingsToggle(
                            text: "Check for DDC responsiveness periodically", setting: $detectResponsiveness,
                            help: """
                            Detects when DDC becomes unresponsive and presents
                            the choice to switch to Software Dimming.
                            """
                        )
                    }
                    if dc.activeDisplayList.contains(where: { $0.control is NetworkControl }) {
                        SettingsToggle(
                            text: "Disable Network Controller video ", setting: $disableControllerVideo,
                            help: """
                            When using "Network Control" with a Raspberry Pi, it might be
                            helpful to disable the Pi desktop if you don't need it.
                            """
                        )
                    }
                    SettingsToggle(
                        text: "Check for network light sensors periodically", setting: $sensorCheckerEnabled,
                        help: """
                        To enable "Sensor Mode", Lunar periodically checks if a wireless light
                        sensor is available using local DNS requests. You can disable this if
                        you never intend to use a wireless ambient light sensor.
                        """
                    )
                    Divider()
                    Group {
                        Text("EXPERIMENTAL!")
                            .foregroundColor(Color.red)
                            .bold()
                        Text("Don't use unless really needed or asked by the developer")
                            .foregroundColor(Color.red)
                            .font(.caption)
                        SettingsToggle(
                            text: "Disable usage of Gamma API completely", setting: $gammaDisabledCompletely,
                            help: """
                            Experimental: for people running into macOS bugs like the color profile
                            being constantly reset, display turning to monochrome or HDR being disabled,
                            this could be a safe measure to ensure Lunar never touches the Gamma API of macOS.

                            This will disable or cripple the following features:

                            • XDR Brightness
                            • Facelight
                            • Blackout
                            • Software Dimming
                            • Sub-zero Dimming
                            """
                        )
                        if dc.activeDisplayList.contains(where: \.hasDDC) {
                            SettingsToggle(
                                text: "Auto restart Lunar when DDC fails", setting: $autoRestartOnFailedDDC,
                                help: """
                                Experimental: for people running into macOS bugs where a monitor can no longer
                                be controlled. You might see a lock icon when brightness keys are pressed.

                                To avoid jarring brightness changes, this will not restart the app
                                if any of the following features are in active use:

                                • XDR Brightness
                                • Facelight
                                • Blackout
                                • Sub-zero Dimming
                                """
                            )
                            SettingsToggle(
                                text: "Avoid safety checks", setting: $autoRestartOnFailedDDCSooner,
                                help: """
                                Don't wait for the detection of DDC fail to happen more than once, and restart
                                the app even if it could cause a jarring brightness change.
                                """
                            ).padding(.leading)

                            SettingsToggle(
                                text: "Delay DDC commands after wake", setting: $delayDDCAfterWake,
                                help: """
                                Experimental: for people running into monitor bugs like the video signal being
                                lost or screen not waking up after system sleep, this could be a safe measure
                                to ensure Lunar doesn't send any DDC command until the monitor connection
                                is fully established.

                                This will disable or cripple the following features:

                                • Smooth transitions
                                • DDC responsiveness checker
                                • Re-applying color gain on wake
                                • Re-applying brightness/contrast on wake
                                """
                            )
                            HStack {
                                let secondsBinding = Binding<Float>(
                                    get: { waitAfterWakeSeconds.f / 100 },
                                    set: { waitAfterWakeSeconds = ($0 * 100).i }
                                )
                                BigSurSlider(
                                    percentage: secondsBinding,
                                    image: "clock.circle",
                                    color: Color.lightGray,
                                    backgroundColor: Color.grayMauve.opacity(0.1),
                                    knobColor: Color.lightGray,
                                    showValue: .constant(true),
                                    disabled: !$delayDDCAfterWake
                                )
                                .padding(.leading)

                                SwiftUI.Button("Reset") { waitAfterWakeSeconds = 30 }
                                    .buttonStyle(FlatButton(
                                        color: Color.lightGray,
                                        textColor: Color.darkGray,
                                        radius: 10,
                                        verticalPadding: 3
                                    ))
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .disabled(!delayDDCAfterWake)
                            }
                            if delayDDCAfterWake {
                                Text("Lunar will wait \(waitAfterWakeSeconds) seconds before sending\nthe first DDC command after screen wake")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.black.opacity(0.4))
                                    .frame(height: 28, alignment: .topLeading)
                                    .fixedSize()
                                    .lineLimit(2)
                                    .padding(.leading, 20)
                                    .padding(.top, -5)
                            }
                        }
                        if nonManualMode {
                            SettingsToggle(
                                text: "Disable cliff detection for auto-learning", setting: $disableCliffDetection,
                                help: """
                                The Cliff Detection algorithm is a safe guard that avoids having Lunar learn
                                a very low brightness and a very high brightness very close together.
                                (e.g. 5% at 10lux, 100% at 20lux)

                                That would cause constant transitioning between the two learnt brightnesses
                                and very high CPU usage when the ambient light changed continuously.
                                (which happens often when clouds are passing, or when in a moving vehicle)

                                This will disable that safe guard.
                                """
                            )
                        }
                    }
                }
                Spacer()
                Color.clear
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: sensorCheckerEnabled) { enabled in
            Defaults[.sensorHostname] = enabled ? "lunarsensor.local" : ""
        }
    }
}
