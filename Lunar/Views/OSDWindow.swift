import Cocoa
import Combine
import Foundation
import SwiftUI

// MARK: - OSDWindow

open class OSDWindow: NSWindow, NSWindowDelegate {
    convenience init(swiftuiView: AnyView, display: Display, releaseWhenClosed: Bool) {
        self.init(contentRect: .zero, styleMask: .fullSizeContentView, backing: .buffered, defer: true, screen: display.nsScreen)
        self.display = display
        contentViewController = NSHostingController(rootView: swiftuiView)

        level = NSWindow.Level(CGShieldingWindowLevel().i)
        collectionBehavior = [.stationary, .canJoinAllSpaces, .ignoresCycle, .fullScreenDisallowsTiling]
        ignoresMouseEvents = true
        setAccessibilityRole(.popover)
        setAccessibilitySubrole(.unknown)

        backgroundColor = .clear
        contentView?.bg = .clear
        isOpaque = false
        hasShadow = false
        styleMask = [.fullSizeContentView]
        hidesOnDeactivate = false
        isReleasedWhenClosed = releaseWhenClosed
        delegate = self
    }

    open func show(
        at point: NSPoint? = nil,
        closeAfter closeMilliseconds: Int = 3050,
        fadeAfter fadeMilliseconds: Int = 2000,
        verticalOffset: CGFloat? = nil
    ) {
        guard let screen = display?.nsScreen else { return }
        if let point {
            setFrameOrigin(point)
        } else {
            let wsize = frame.size
            let sframe = screen.frame
            setFrameOrigin(CGPoint(
                x: (sframe.width / 2 - wsize.width / 2) + sframe.origin.x,
                y: sframe.origin.y + (verticalOffset ?? CachedDefaults[.customOSDVerticalOffset].cg)
            ))
        }

        contentView?.superview?.alphaValue = 1
        wc.showWindow(nil)
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()

        endFader = nil
        closer = nil
        fader = nil

        guard closeMilliseconds > 0 else { return }
        fader = mainAsyncAfter(ms: fadeMilliseconds) { [weak self] in
            guard let s = self, s.isVisible else { return }
            s.contentView?.superview?.transition(1)
            s.contentView?.superview?.alphaValue = 0.01
            s.endFader = mainAsyncAfter(ms: 1000) { [weak self] in
                self?.contentView?.superview?.alphaValue = 0
            }
            s.closer = mainAsyncAfter(ms: closeMilliseconds) { [weak self] in
                self?.close()
            }
        }
    }

    public func hide() {
        fader = nil
        endFader = nil
        closer = nil

        if let v = contentView?.superview {
            v.alphaValue = 0.0
        }
        close()
        windowController?.close()
    }

    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard isReleasedWhenClosed else { return true }
        windowController?.window = nil
        windowController = nil
        return true
    }

    weak var display: Display?
    lazy var wc = NSWindowController(window: self)

    var closer: DispatchWorkItem? { didSet { oldValue?.cancel() } }
    var fader: DispatchWorkItem? { didSet { oldValue?.cancel() } }
    var endFader: DispatchWorkItem? { didSet { oldValue?.cancel() } }
}

extension AnyView {
    var state: State<Self> { State(initialValue: self) }
}

extension ExpressibleByNilLiteral {
    var state: State<Self> { State(initialValue: self) }
}

extension Color {
    var state: State<Self> { State(initialValue: self) }
}

extension BinaryInteger {
    var state: State<Self> { State(initialValue: self) }
}

extension FloatingPoint {
    var state: State<Self> { State(initialValue: self) }
}

extension AnyHashable {
    var state: State<Self> { State(initialValue: self) }
}

extension String {
    var state: State<Self> { State(initialValue: self) }
}

extension Float {
    var cg: CGFloat { CGFloat(self) }
}

func st<T>(_ v: T) -> State<T> {
    State(initialValue: v)
}

extension Color {
    var isDark: Bool {
        NSColor(self).hsb.2 < 65
    }

    var textColor: Color {
        isDark ? .white : .black
    }
}

// MARK: - BigSurSlider

public struct BigSurSlider: View {
    public init(
        percentage: Binding<Float>,
        sliderWidth: CGFloat = 200,
        sliderHeight: CGFloat = 22,
        image: String? = nil,
        imageBinding: Binding<String?>? = nil,
        color: Color? = nil,
        colorBinding: Binding<Color?>? = nil,
        backgroundColor: Color = .black.opacity(0.1),
        backgroundColorBinding: Binding<Color>? = nil,
        knobColor: Color? = nil,
        knobColorBinding: Binding<Color?>? = nil,
        knobTextColor: Color? = nil,
        knobTextColorBinding: Binding<Color?>? = nil,
        showValue: Binding<Bool>? = nil,
        acceptsMouseEvents: Binding<Bool>? = nil,
        disabled: Binding<Bool>? = nil,
        enableText: String? = nil,
        mark: Binding<Float>? = nil,
        onSettingPercentage: ((Float) -> Void)? = nil
    ) {
        _knobColor = .constant(knobColor)
        _knobTextColor = .constant(knobTextColor)

        _percentage = percentage
        _sliderWidth = sliderWidth.state
        _sliderHeight = sliderHeight.state
        _image = imageBinding ?? .constant(image)
        _color = colorBinding ?? .constant(color)
        _showValue = showValue ?? .constant(false)
        _backgroundColor = backgroundColorBinding ?? .constant(backgroundColor)
        _acceptsMouseEvents = acceptsMouseEvents ?? .constant(true)
        _disabled = disabled ?? .constant(false)
        _enableText = State(initialValue: enableText)
        _mark = mark ?? .constant(0)

        _knobColor = knobColorBinding ?? colorBinding ?? .constant(knobColor ?? colors.accent)
        _knobTextColor = knobTextColorBinding ?? .constant(knobTextColor ?? ((color ?? Colors.peach).textColor))
        self.onSettingPercentage = onSettingPercentage
    }

    public var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width - self.sliderHeight
            let cgPercentage = cap(percentage, minVal: 0, maxVal: 1).cg

            ZStack(alignment: .leading) {
                Rectangle()
                    .foregroundColor(backgroundColor)
                ZStack(alignment: .leading) {
                    Rectangle()
                        .foregroundColor(color ?? colors.accent)
                        .frame(width: cgPercentage == 1 ? geometry.size.width : w * cgPercentage + sliderHeight / 2)
                    if let image {
                        Image(systemName: image)
                            .resizable()
                            .frame(width: 12, height: 12, alignment: .center)
                            .font(.body.weight(.heavy))
                            .frame(width: sliderHeight - 7, height: sliderHeight - 7)
                            .foregroundColor(Color.black.opacity(0.5))
                            .offset(x: 3, y: 0)
                    }
                    ZStack {
                        Circle()
                            .foregroundColor(knobColor)
                            .shadow(color: Colors.blackMauve.opacity(percentage > 0.3 ? 0.3 : percentage.d), radius: 5, x: -1, y: 0)
                            .frame(width: sliderHeight, height: sliderHeight, alignment: .trailing)
                            .brightness(env.draggingSlider && hovering ? -0.2 : 0)
                        if showValue {
                            Text((percentage * 100).str(decimals: 0))
                                .foregroundColor(knobTextColor)
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .allowsHitTesting(false)
                        }
                    }.offset(
                        x: cgPercentage * w,
                        y: 0
                    )
                    if mark > 0 {
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(Color.red.opacity(0.7))
                            .frame(width: 3, height: sliderHeight - 5, alignment: .center)
                            .offset(
                                x: cap(mark, minVal: 0, maxVal: 1).cg * w,
                                y: 0
                            ).animation(.jumpySpring, value: mark)
                    }
                }
                .disabled(disabled)
                .contrast(disabled ? 0.4 : 1.0)
                .saturation(disabled ? 0.4 : 1.0)

                if disabled, hovering, let enableText {
                    SwiftUI.Button(enableText) {
                        disabled = false
                    }
                    .buttonStyle(FlatButton(
                        color: Colors.red.opacity(0.7),
                        textColor: .white,
                        horizontalPadding: 6,
                        verticalPadding: 2
                    ))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .transition(.scale.animation(.fastSpring))
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(width: sliderWidth, height: sliderHeight)
            .cornerRadius(20)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard acceptsMouseEvents, !disabled else { return }
                        if !env.draggingSlider {
                            if draggingSliderSetter == nil {
                                draggingSliderSetter = mainAsyncAfter(ms: 200) {
                                    env.draggingSlider = true
                                }
                            } else {
                                draggingSliderSetter = nil
                                env.draggingSlider = true
                            }
                        }

                        self.percentage = cap(Float(value.location.x / geometry.size.width), minVal: 0, maxVal: 1)
                        self.onSettingPercentage?(self.percentage)
                    }
                    .onEnded { value in
                        guard acceptsMouseEvents, !disabled else { return }
                        draggingSliderSetter = nil
                        self.percentage = cap(Float(value.location.x / geometry.size.width), minVal: 0, maxVal: 1)
                        self.onSettingPercentage?(self.percentage)
                        env.draggingSlider = false
                    }
            )
            #if os(macOS)
            .onHover { hov in
                hovering = hov
                guard acceptsMouseEvents, !disabled else { return }

                if hovering {
                    lastCursorPosition = NSEvent.mouseLocation
                    hoveringSliderSetter = mainAsyncAfter(ms: 200) {
                        guard lastCursorPosition != NSEvent.mouseLocation else { return }
                        env.hoveringSlider = hovering
                    }
                    trackScrollWheel()
                } else {
                    hoveringSliderSetter = nil
                    env.hoveringSlider = false
                }
            }
            #endif
        }
        .frame(width: sliderWidth, height: sliderHeight)
        .onChange(of: env.draggingSlider) { tracking in
            AppleNativeControl.sliderTracking = tracking || hovering
            GammaControl.sliderTracking = tracking || hovering
            DDCControl.sliderTracking = tracking || hovering
        }
        .onChange(of: hovering) { tracking in
            AppleNativeControl.sliderTracking = tracking || env.draggingSlider
            GammaControl.sliderTracking = tracking || env.draggingSlider
            DDCControl.sliderTracking = tracking || env.draggingSlider
        }
    }

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.colors) var colors
    @EnvironmentObject var env: EnvState

    @Binding var percentage: Float
    @State var sliderWidth: CGFloat = 200
    @State var sliderHeight: CGFloat = 22
    @Binding var image: String?
    @Binding var color: Color?
    @Binding var backgroundColor: Color
    @Binding var knobColor: Color?
    @Binding var knobTextColor: Color?
    @Binding var showValue: Bool

    @State var scrollWheelListener: Cancellable?

    @State var hovering = false
    @State var enableText: String? = nil
    @State var lastCursorPosition = NSEvent.mouseLocation
    @Binding var acceptsMouseEvents: Bool
    @Binding var disabled: Bool
    @Binding var mark: Float

    var onSettingPercentage: ((Float) -> Void)?

    #if os(macOS)
        func trackScrollWheel() {
            guard scrollWheelListener == nil else { return }
            scrollWheelListener = NSApp.publisher(for: \.currentEvent)
                .filter { event in event?.type == .scrollWheel }
                .throttle(for: .milliseconds(20), scheduler: DispatchQueue.main, latest: true)
                .sink { event in
                    guard hovering, env.hoveringSlider, let event, event.momentumPhase.rawValue == 0 else {
                        if let event, event.scrollingDeltaX + event.scrollingDeltaY == 0, event.phase.rawValue == 0,
                           env.draggingSlider
                        {
                            env.draggingSlider = false
                        }
                        return
                    }

                    let delta = Float(event.scrollingDeltaX) * (event.isDirectionInvertedFromDevice ? -1 : 1)
                        + Float(event.scrollingDeltaY) * (event.isDirectionInvertedFromDevice ? 1 : -1)

                    switch event.phase {
                    case .changed, .began, .mayBegin:
                        if !env.draggingSlider {
                            env.draggingSlider = true
                        }
                    case .ended, .cancelled, .stationary:
                        if env.draggingSlider {
                            env.draggingSlider = false
                        }
                    default:
                        if delta == 0, env.draggingSlider {
                            env.draggingSlider = false
                        }
                    }
                    self.percentage = cap(self.percentage - (delta / 100), minVal: 0, maxVal: 1)
                    self.onSettingPercentage?(self.percentage)
                }
        }
    #endif
}

extension NSEvent.Phase {
    var str: String {
        switch self {
        case .mayBegin: return "mayBegin"
        case .began: return "began"
        case .changed: return "changed"
        case .stationary: return "stationary"
        case .cancelled: return "cancelled"
        case .ended: return "ended"
        default:
            return "phase(\(rawValue))"
        }
    }
}

var hoveringSliderSetter: DispatchWorkItem? {
    didSet { oldValue?.cancel() }
}

var draggingSliderSetter: DispatchWorkItem? {
    didSet { oldValue?.cancel() }
}

// MARK: - Colors

public struct Colors {
    public init(_ colorScheme: SwiftUI.ColorScheme = .light, accent: Color) {
        self.accent = accent
        self.colorScheme = colorScheme
        bg = BG(colorScheme: colorScheme)
        fg = FG(colorScheme: colorScheme)
    }

    public struct FG {
        public var colorScheme: SwiftUI.ColorScheme

        public var isDark: Bool { colorScheme == .dark }
        public var isLight: Bool { colorScheme == .light }

        var gray: Color { isDark ? Colors.lightGray : Colors.darkGray }
        var primary: Color { isDark ? .white : .black }
    }

    public struct BG {
        public var colorScheme: SwiftUI.ColorScheme

        public var isDark: Bool { colorScheme == .dark }
        public var isLight: Bool { colorScheme == .light }

        var gray: Color { isDark ? Colors.darkGray : Colors.lightGray }
        var primary: Color { isDark ? .black : .white }
    }

    public static var light = Colors(.light, accent: Colors.lunarYellow)
    public static var dark = Colors(.dark, accent: Colors.peach)

    public static let darkGray = Color(hue: 0, saturation: 0.01, brightness: 0.32)
    public static let blackGray = Color(hue: 0.03, saturation: 0.12, brightness: 0.18)
    public static let lightGray = Color(hue: 0, saturation: 0.0, brightness: 0.92)

    public static let red = Color(hue: 0.98, saturation: 0.82, brightness: 1.00)
    public static let lightGold = Color(hue: 0.09, saturation: 0.28, brightness: 0.94)
    public static let grayMauve = Color(hue: 252 / 360, saturation: 0.29, brightness: 0.43)
    public static let mauve = Color(hue: 252 / 360, saturation: 0.29, brightness: 0.23)
    public static let pinkMauve = Color(hue: 0.95, saturation: 0.76, brightness: 0.42)
    public static let blackMauve = Color(
        hue: 252 / 360,
        saturation: 0.08,
        brightness:
        0.12
    )
    public static let yellow = Color(hue: 39 / 360, saturation: 1.0, brightness: 0.64)
    public static let lunarYellow = Color(hue: 0.11, saturation: 0.47, brightness: 1.00)
    public static let sunYellow = Color(hue: 0.1, saturation: 0.57, brightness: 1.00)
    public static let peach = Color(hue: 0.08, saturation: 0.42, brightness: 1.00)
    public static let blue = Color(hue: 214 / 360, saturation: 1.0, brightness: 0.54)
    public static let green = Color(hue: 141 / 360, saturation: 0.59, brightness: 0.58)
    public static let lightGreen = Color(hue: 141 / 360, saturation: 0.50, brightness: 0.83)

    public static let xdr = Color(hue: 0.61, saturation: 0.26, brightness: 0.78)
    public static let subzero = Color(hue: 0.98, saturation: 0.56, brightness: 1.00)

    public var accent: Color
    public var colorScheme: SwiftUI.ColorScheme

    public var bg: BG
    public var fg: FG

    public var isDark: Bool { colorScheme == .dark }
    public var isLight: Bool { colorScheme == .light }
    public var inverted: Color { isDark ? .black : .white }
    public var invertedGray: Color { isDark ? Colors.darkGray : Colors.lightGray }
    public var gray: Color { isDark ? Colors.lightGray : Colors.darkGray }
}

// MARK: - ColorsKey

private struct ColorsKey: EnvironmentKey {
    public static let defaultValue = Colors.light
}

public extension EnvironmentValues {
    var colors: Colors {
        get { self[ColorsKey.self] }
        set { self[ColorsKey.self] = newValue }
    }
}

public extension View {
    func colors(_ colors: Colors) -> some View {
        environment(\.colors, colors)
    }
}

// MARK: - BrightnessOSDView

struct BrightnessOSDView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.colors) var colors

    @ObservedObject var osd = OSD_STATE

    var nsImage: NSImage? {
        guard let img = NSImage(systemSymbolName: osd.image, accessibilityDescription: nil) else {
            return nil
        }
        img.resizingMode = .stretch

        return img
    }

    var body: some View {
        ZStack {
            VStack {
                Image(systemName: osd.image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: NATIVE_OSD_WIDTH * 0.5, height: NATIVE_OSD_WIDTH * 0.5)
                    .font(.system(size: 48, weight: .light, design: .rounded))
                    .foregroundColor(.primary.opacity(0.75))

                Text(osd.text).font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary.opacity(0.75))
            }

            let value = mapNumber(osd.value, fromLow: 0, fromHigh: 1, toLow: 0, toHigh: 160).cg

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 0.0, y: 0))
                    path.addLine(to: CGPoint(x: 161, y: 0))
                }
                .stroke(style: StrokeStyle(lineWidth: 8))
                .foregroundColor(Color.black.opacity(0.9))
                Path { path in
                    path.move(to: CGPoint(x: 1, y: 0))
                    path.addLine(to: CGPoint(x: value, y: 0))
                }
                .stroke(style: StrokeStyle(lineWidth: 6, dash: [9, 1]))
                .foregroundColor(osd.color)
                .shadow(color: osd.glowRadius == 0 ? .clear : osd.color, radius: osd.value.cg * osd.glowRadius, x: 0, y: 0)
                .animation(.easeOut(duration: 0.15), value: osd.value)
            }.offset(y: NATIVE_OSD_WIDTH * 0.78)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
        .padding(.top, 20)
        .background(
            VisualEffectBlur(material: .osd, blendingMode: .behindWindow, state: .active)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
        .frame(width: NATIVE_OSD_WIDTH, height: NATIVE_OSD_WIDTH, alignment: .center)
        .fixedSize()
        .colors(colorScheme == .dark ? .dark : .light)
    }
}

// MARK: - AutoOSDView

struct AutoOSDView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.colors) var colors
    @ObservedObject var display: Display
    @Binding var done: Bool
    @State var title: String
    @State var subtitle: String
    @State var color: Color
    @State var icon: String
    @State var progress: Float = 0.0
    @State var opacity: CGFloat = 1.0

    @State var timer: Timer?

    var body: some View {
        VStack {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
            Text(subtitle)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .scaledToFit()
                .minimumScaleFactor(.leastNonzeroMagnitude)
                .padding(.horizontal, 10)

            BigSurSlider(
                percentage: $progress,
                image: icon,
                color: color.opacity(0.8),
                backgroundColor: color.opacity(colorScheme == .dark ? 0.1 : 0.2),
                knobColor: .clear,
                showValue: .constant(false),
                acceptsMouseEvents: .constant(false)
            )
            HStack(spacing: 3) {
                Text("Press")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                Text("esc")
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.top, 1)
                    .padding(.bottom, 2)
                    .padding(.horizontal, 4)
                    .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(.black))
                Text("to abort")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 30)
        .padding(.top, 30)
        .background(
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow, state: .active)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .shadow(color: Colors.blackMauve.opacity(0.2), radius: 8, x: 0, y: 4)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill((colorScheme == .dark ? Colors.blackMauve : Color.white).opacity(0.4))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
            }
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 30)
        .colors(colorScheme == .dark ? .dark : .light)
        .onAppear {
            let step = 0.01 / (AUTO_OSD_DEBOUNCE_SECONDS - 0.5).f
            timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { t in
                guard progress < 1, !done else {
                    t.invalidate()
                    withAnimation(.easeOut(duration: 0.25)) { opacity = 0.0 }
                    display.autoOsdWindowController?.close()
                    return
                }
                progress += step
            }
            timer?.tolerance = 0
        }
        .onDisappear {
            timer?.invalidate()
        }
        .opacity(opacity)
    }
}

let AUTO_OSD_DEBOUNCE_SECONDS = 4.0
let NATIVE_OSD_WIDTH: CGFloat = 200
let OSD_WIDTH: CGFloat = 300

// MARK: - OSDState

class OSDState: ObservableObject {
    @Published var image = "sun.max"
    @Published var value: Float = 1.0
    @Published var text = ""
    @Published var color: Color = .white
    @Published var glowRadius: CGFloat = 5
}

let OSD_STATE = OSDState()

extension Display {
    func hideSoftwareOSD() {
        mainAsync { [weak self] in
            guard let osd = self?.osdWindowController?.window as? OSDWindow else { return }
            osd.hide()
            self?.osdWindowController = nil
        }
    }

    func showSoftwareOSD(image: String, value: Float, text: String, color: Color, glowRadius: CGFloat = 5) {
        mainAsync { [weak self] in
            guard let self else { return }

            OSD_STATE.image = image
            OSD_STATE.value = value
            OSD_STATE.text = text
            OSD_STATE.color = color
            OSD_STATE.glowRadius = glowRadius

            if self.osdWindowController == nil {
                let view = BrightnessOSDView()
                self.osdWindowController = OSDWindow(
                    swiftuiView: AnyView(view),
                    display: self,
                    releaseWhenClosed: false
                ).wc
            }

            guard let osd = self.osdWindowController?.window as? OSDWindow else { return }

            osd.show(verticalOffset: 140)
        }
    }

    func showAutoBlackOutOSD() {
        mainAsync { [weak self] in
            guard let self, !self.blackOutEnabled else {
                self?.autoOsdWindowController?.close()
                return
            }
            self.autoOsdWindowController?.close()
            self.autoOsdWindowController = OSDWindow(
                swiftuiView: AnyView(
                    AutoOSDView(
                        display: self,
                        done: .oneway { [weak self] in self?.blackOutEnabled ?? true },
                        title: "Turning off",
                        subtitle: self.name,
                        color: Colors.red,
                        icon: "power.circle.fill"
                    )
                    .colors(darkMode ? .dark : .light)
                    .environmentObject(EnvState())
                ),
                display: self, releaseWhenClosed: true
            ).wc

            guard let osd = self.autoOsdWindowController?.window as? OSDWindow else { return }

            osd.show(closeAfter: 1000, fadeAfter: ((AUTO_OSD_DEBOUNCE_SECONDS + 0.5) * 1000).i)
        }
    }

    func showAutoXdrOSD(xdrEnabled: Bool, reason: String) {
        mainAsync { [weak self] in
            guard let self else { return }

            self.autoOsdWindowController?.close()
            self.autoOsdWindowController = OSDWindow(
                swiftuiView: AnyView(
                    AutoOSDView(
                        display: self,
                        done: .oneway { [weak self] in (self?.enhanced ?? xdrEnabled) == xdrEnabled },
                        title: xdrEnabled ? "Activating XDR" : "Disabling XDR",
                        subtitle: reason,
                        color: Colors.xdr,
                        icon: "sun.max.circle.fill"
                    )
                    .colors(darkMode ? .dark : .light)
                    .environmentObject(EnvState())
                ),
                display: self, releaseWhenClosed: true
            ).wc

            guard let osd = self.autoOsdWindowController?.window as? OSDWindow else { return }

            osd.show(closeAfter: 1000, fadeAfter: ((AUTO_OSD_DEBOUNCE_SECONDS + 0.5) * 1000).i)
        }
    }
}

import Cocoa
import Foundation
import SwiftUI

// MARK: - PanelWindow

open class PanelWindow: NSWindow {
    public convenience init(swiftuiView: AnyView) {
        self.init(contentViewController: NSHostingController(rootView: swiftuiView))

        level = .floating
        setAccessibilityRole(.popover)
        setAccessibilitySubrole(.unknown)

        backgroundColor = .clear
        contentView?.bg = .clear
        contentView?.layer?.masksToBounds = false
        isOpaque = false
        hasShadow = false
        styleMask = [.fullSizeContentView]
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
    }

    override open var canBecomeKey: Bool { true }

    open func show(at point: NSPoint? = nil, animate: Bool = false) {
        if let point {
            if animate {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.15
                    ctx.timingFunction = .easeOut
                    ctx.allowsImplicitAnimation = true
                    setFrame(NSRect(origin: point, size: frame.size), display: true, animate: true)
                }
            } else {
                setFrameOrigin(point)
            }
        } else {
            center()
        }

        guard !isVisible else { return }

        wc.showWindow(nil)
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    public func forceClose() {
        wc.close()
        wc.window = nil
        close()
    }

    private lazy var wc = NSWindowController(window: self)
}
