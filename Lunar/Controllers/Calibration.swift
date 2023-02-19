import Foundation
import SwiftUI

struct DisplayCalibrationView: View {
    @ObservedObject var display: Display
    #if arch(arm64)
        @State var nitsRange: ClosedRange<Float>
    #endif
    @State var contrastRange: ClosedRange<Float>

    @State var apply = true

    var body: some View {
        VStack(spacing: 4) {
            Text(display.name)
                .font(.system(size: 32, weight: .black))
                .foregroundColor(.white)
            VStack(spacing: 30) {
                #if arch(arm64)
                    RangedSliderView(currentValue: $nitsRange, sliderBounds: 0 ... 1000, unit: "nits")
                        .onChange(of: display.minNits) { minNits in
                            guard apply else { return }
                            withoutApply {
                                nitsRange = minNits.f ... display.maxNits.f
                            }
                        }
                        .onChange(of: display.maxNits) { maxNits in
                            guard apply else { return }
                            withoutApply {
                                nitsRange = display.minNits.f ... maxNits.f
                            }
                        }
                        .onChange(of: nitsRange) { nitsRange in
                            guard apply else { return }
                            withoutApply {
                                let newMinNits = nitsRange.lowerBound.intround
                                if newMinNits != display.minNits {
                                    display.minNits = newMinNits
                                    display.brightness = display.minBrightness
                                    if let source = displayController.sourceDisplay, source.id != display.id, let spline = source.nitsSpline {
                                        source.brightness = cap(spline(newMinNits.d), minVal: source.minBrightness.doubleValue, maxVal: source.maxBrightness.doubleValue).ns
                                    }
                                    return
                                }

                                let newMaxNits = nitsRange.upperBound.intround
                                if newMaxNits != display.maxNits {
                                    display.maxNits = newMaxNits
                                    display.brightness = display.maxBrightness
                                    if let source = displayController.sourceDisplay, source.id != display.id, let spline = source.nitsSpline {
                                        source.brightness = cap(spline(newMaxNits.d), minVal: source.minBrightness.doubleValue, maxVal: source.maxBrightness.doubleValue).ns
                                    }
                                }
                            }
                        }
                #endif
                if display.hasDDC {
                    RangedSliderView(currentValue: $contrastRange, sliderBounds: 0 ... 100, unit: "contrast")
                        .onChange(of: contrastRange) { contrastRange in
                            let newMinContrast = contrastRange.lowerBound.intround
                            if newMinContrast != display.minContrast.intValue {
                                display.withoutApply {
                                    display.minContrast = newMinContrast.ns
                                }
                                display.contrast = display.minContrast
                                return
                            }

                            let newMaxContrast = contrastRange.upperBound.intround
                            if newMaxContrast != display.maxContrast.intValue {
                                display.withoutApply {
                                    display.maxContrast = newMaxContrast.ns
                                }
                                display.contrast = display.maxContrast
                            }
                        }
                }
            }
            .padding(30)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.06)))
        }.onAppear {
            #if arch(arm64)
                nitsRange = display.minNits.f ... display.maxNits.f
            #endif
            contrastRange = display.minContrast.floatValue ... display.maxContrast.floatValue
        }
    }

    @inline(__always) func withoutApply(_ block: () -> Void) {
        apply = false
        block()
        apply = true
    }

}

extension DisplayController {
    func stopCalibration() {
        //            nitsCurveComputeTask = nil
        if !NightShift.isEnabled, NightShift.scheduledState {
            NightShift.enable()
        } else if usingFlux {
            launchFlux()
        }

        activeDisplayList.forEach { d in
            if d.isSource, !d.adaptive {
                d.systemAdaptiveBrightness = true
            }
            d.hideCalibrationView()

            if d.brightnessBeforeFacelight.intValue > 0 {
                d.brightness = d.brightnessBeforeFacelight
            }
            if d.contrastBeforeFacelight.intValue > 0 {
                d.contrast = d.contrastBeforeFacelight
            }
        }

        if let sourceDisplay {
            if sourceDisplay.brightnessBeforeFacelight.intValue > 0 {
                sourceDisplay.brightness = sourceDisplay.brightnessBeforeFacelight
            }
            if sourceDisplay.contrastBeforeFacelight.intValue > 0 {
                sourceDisplay.contrast = sourceDisplay.contrastBeforeFacelight
            }
        }

        calibrating = false
    }
    func startCalibration() {
        calibrating = true

        if NightShift.isEnabled {
            NightShift.disable()
        }
        if fluxRunning {
            fluxApp()?.terminate()
        }

        activeDisplayList
            .filter(\.blackOutEnabled)
            .map(\.id).enumerated().forEach { i, id in
                mainAsyncAfter(ms: i * 1000) { [self] in
                    guard let d = activeDisplays[id] else { return }
                    d.resetSoftwareControl()
                    lastBlackOutToggleDate = .distantPast
                    blackOut(display: d.id, state: .off)
                    d.blackOutEnabled = false
                    d.mirroredBeforeBlackOut = false
                }
            }

        if let sourceDisplay {
            sourceDisplay.brightnessBeforeFacelight = sourceDisplay.brightness
            sourceDisplay.contrastBeforeFacelight = sourceDisplay.contrast
        }

        activeDisplayList
            .forEach { d in
                if d.faceLightEnabled {
                    d.disableFaceLight(smooth: false)
                }
                if d.xdr {
                    d.xdr = false
                }
                if d.subzero {
                    d.subzero = false
                }
                if d.systemAdaptiveBrightness {
                    d.systemAdaptiveBrightness = false
                }
                d.brightness = d.maxBrightness
                d.contrast = d.maxContrast

                d.brightnessBeforeFacelight = d.brightness
                d.contrastBeforeFacelight = d.contrast

                d.showCalibrationView()
            }

        //            computeSourceNitsCurve()
    }

}

struct CalibrationScreenView: View {
    @ObservedObject var display: Display
    var screen: NSScreen

    var body: some View {
        let whites = (244 ... 254).map { $0 }
        let size = min(screen.frame.width, screen.frame.height) / 7
        let squareSize = size / 4
        ZStack(alignment: .bottomTrailing) {
            VStack {
                VStack(spacing: 0) {
                    Text("""
                    Below are 12 light grey checkerboard patterns on a white background. Each of them should be distinguishable from the background, which has value 255.

                    Adjust max contrast where possible until the 254 pattern is barely visible.
                    """)
                    .foregroundColor(Color(white: 0.5))
                    .frame(width: size * 4.75, alignment: .leading)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .padding(.horizontal, size * 0.3)
                    .padding(.vertical, size * 0.1)
                    .background(Color(white: 0.1))

                    LazyVGrid(columns: [.init(.fixed(size), spacing: squareSize), .init(.fixed(size), spacing: squareSize), .init(.fixed(size), spacing: squareSize), .init(.fixed(size), spacing: squareSize)], spacing: squareSize) {
                        ForEach([200] + whites, id: \.self) { white in
                            CheckerView(white: white, squareSize: squareSize).fixedSize()
                        }
                    }
                    .padding(.horizontal, size * 0.3)
                    .padding(.vertical, size * 0.2)
                    .fixedSize()
                    .background(Color(white: 1))
                }
                .clipShape(RoundedRectangle(cornerRadius: size / 12, style: .continuous))

                if !display.isSource {
                    #if arch(arm64)
                        let view = DisplayCalibrationView(
                            display: display,
                            nitsRange: display.minNits.f ... display.maxNits.f,
                            contrastRange: display.minContrast.floatValue ... display.maxContrast.floatValue
                        )
                    #else
                        let view = DisplayCalibrationView(
                            display: display,
                            contrastRange: display.minContrast.floatValue ... display.maxContrast.floatValue
                        )
                    #endif
                    view
                        .frame(width: 300, height: 150)
                        .padding(.top)
                }

            }
            .frame(width: screen.frame.width, height: screen.frame.height)
            .fixedSize()
            .background(Color(white: 0.5))

            Text("Press Esc to close")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Color(white: 0.6))
                .padding(40)
        }
    }
}

extension Display {
    func hideCalibrationView() {
        mainAsync { [weak self] in
            guard let osd = self?.calibrationWindowController?.window as? OSDWindow else { return }
            osd.hide()
            self?.calibrationWindowController = nil

            menuWindow?.level = .floating
            appDelegate?.statusItemButtonController?.repositionWindow(animate: true)
        }
    }

    func showCalibrationView() {
        mainAsync { [weak self] in
            guard let self, let nsScreen = self.nsScreen else { return }

            if self.calibrationWindowController == nil {
                let view = CalibrationScreenView(display: self, screen: nsScreen)
                self.calibrationWindowController = OSDWindow(
                    swiftuiView: AnyView(view),
                    display: self,
                    releaseWhenClosed: true,
                    level: .statusBar,
                    ignoresMouseEvents: false
                ).wc
            }

            guard let osd = self.calibrationWindowController?.window as? OSDWindow else { return }
            CachedDefaults[.showOptionsMenu] = false

            if let w = menuWindow, let s = NSScreen.main {
                w.level = .popUpMenu
                let point = NSPoint(x: s.frame.maxX - (w.frame.width / 2 + MENU_WIDTH / 2 + 20), y: s.frame.maxY - (w.frame.height + 20))
                w.show(at: point, animate: true)
            }

            osd.show(at: self.nsScreen?.frame.origin ?? .zero, closeAfter: 0, fadeAfter: 0, verticalOffset: 0)
        }
    }

}
// @ViewBuilder var computingNitsProgress: some View {
//         if let id = dc.computingNitsCurveID, let sourceDisplay = dc.activeDisplays[id] {
//             VStack {
//                 Text("Computing nits curve for").font(.system(size: 13))
//                 Text(sourceDisplay.name).font(.system(size: 13, weight: .semibold))
//                 ProgressView(value: dc.computingNitsCurveProgress)
//                     .frame(width: 200)
//                     .padding(.top)
//             }
//             .frame(maxWidth: .infinity, maxHeight: .infinity)
//             .background(colors.inverted.opacity(0.9))
//         }
//     }

struct RangedSliderView: View {
    @Binding var currentValue: ClosedRange<Float>
    @State var sliderBounds: ClosedRange<Int>
    @State var unit: String?
    @State var unitAlignment: Alignment = .trailing

    var body: some View {
        GeometryReader { geomentry in
            sliderView(sliderSize: geomentry.size)
        }
    }

    @ViewBuilder func lineBetweenThumbs(from: CGPoint, to: CGPoint) -> some View {
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }.stroke(Colors.darkGray, lineWidth: 20)
    }

    @ViewBuilder func thumbView(position: CGPoint, value: Float) -> some View {
        ZStack {
            Circle()
                .frame(width: 20, height: 20)
                .foregroundColor(Colors.darkGray)
                .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 2)
                .contentShape(Rectangle())
            Text("\(value.intround)")
                .font(.system(size: 7, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(.leastNonzeroMagnitude)
                .scaledToFit()
                .frame(maxWidth: 16)
                .foregroundColor(.white)
        }
        .frame(width: 20, height: 20)
        .position(x: position.x, y: position.y)
    }

    @ViewBuilder private func sliderView(sliderSize: CGSize) -> some View {
        let sliderViewYCenter = sliderSize.height / 2 + (unit == nil ? 0 : 5.5)
        ZStack(alignment: unitAlignment) {
            if let unit {
                Text(unit)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.4))
                    .offset(x: 0, y: unitAlignment.vertical == .top ? -15 : (unitAlignment.vertical == .bottom ? 15 : 0))
                    .allowsHitTesting(false)
            }
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Colors.darkGray.opacity(0.3))
                    .frame(height: 20)
                    .scaleEffect(x: 1.05)
                ZStack(alignment: .center) {
                    let sliderBoundDifference = sliderBounds.count
                    let stepWidthInPixel = CGFloat(sliderSize.width) / CGFloat(sliderBoundDifference)

                    // Calculate Left Thumb initial position
                    let leftThumbLocation: CGFloat = currentValue.lowerBound == Float(sliderBounds.lowerBound)
                        ? 0
                        : CGFloat(currentValue.lowerBound - Float(sliderBounds.lowerBound)) * stepWidthInPixel

                    // Calculate right thumb initial position
                    let rightThumbLocation = CGFloat(currentValue.upperBound) * stepWidthInPixel

                    // Path between both handles
                    lineBetweenThumbs(from: .init(x: leftThumbLocation, y: sliderViewYCenter), to: .init(x: rightThumbLocation, y: sliderViewYCenter))

                    // Left Thumb Handle
                    let leftThumbPoint = CGPoint(x: leftThumbLocation, y: sliderViewYCenter)
                    thumbView(position: leftThumbPoint, value: Float(currentValue.lowerBound))
                        .highPriorityGesture(DragGesture().onChanged { dragValue in
                            let dragLocation = dragValue.location
                            let xThumbOffset = min(max(0, dragLocation.x), sliderSize.width)

                            let newValue = Float(sliderBounds.lowerBound) + Float(xThumbOffset / stepWidthInPixel)

                            // Stop the range thumbs from colliding each other
                            if newValue.intround < currentValue.upperBound.intround {
                                currentValue = newValue ... currentValue.upperBound
                            }
                        })

                    // Right Thumb Handle
                    thumbView(position: CGPoint(x: rightThumbLocation, y: sliderViewYCenter), value: currentValue.upperBound)
                        .highPriorityGesture(DragGesture().onChanged { dragValue in
                            let dragLocation = dragValue.location
                            let xThumbOffset = min(max(CGFloat(leftThumbLocation), dragLocation.x), sliderSize.width)

                            var newValue = Float(xThumbOffset / stepWidthInPixel) // convert back the value bound
                            newValue = min(newValue, Float(sliderBounds.upperBound))

                            // Stop the range thumbs from colliding each other
                            if newValue.intround > currentValue.lowerBound.intround {
                                currentValue = currentValue.lowerBound ... newValue
                            }
                        })
                }
            }
        }
    }
}

struct Calibration_Previews: PreviewProvider {
    static var previews: some View {
        CalibrationScreenView(display: displayController.externalDisplays.first!, screen: displayController.externalDisplays.first!.nsScreen!)
    }
}
