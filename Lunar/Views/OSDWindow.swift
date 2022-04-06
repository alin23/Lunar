import Cocoa
import Combine
import Foundation
import SwiftUI

// MARK: - OSDWindow

open class OSDWindow: NSWindow {
    // MARK: Lifecycle

    convenience init(swiftuiView: AnyView, display: Display) {
        self.init(contentRect: .zero, styleMask: .fullSizeContentView, backing: .buffered, defer: true, screen: display.screen)
        self.display = display
        contentViewController = NSHostingController(rootView: swiftuiView)

        level = NSWindow.Level(CGShieldingWindowLevel().i)
        collectionBehavior = [.stationary, .canJoinAllSpaces, .ignoresCycle, .fullScreenDisallowsTiling]
//        sharingType = .none
        ignoresMouseEvents = true
        setAccessibilityRole(.popover)
        setAccessibilitySubrole(.unknown)

        backgroundColor = .clear
        contentView?.bg = .clear
        isOpaque = false
        hasShadow = false
        styleMask = [.fullSizeContentView]
        hidesOnDeactivate = false
    }

    // MARK: Open

    open func show(at point: NSPoint? = nil, closeAfter closeMilliseconds: Int = 3050, fadeAfter fadeMilliseconds: Int = 2000) {
        guard let screen = display?.screen else { return }
        if let point = point {
            setFrameOrigin(point)
        } else {
            let wsize = frame.size
            let sframe = screen.visibleFrame
            setFrameOrigin(CGPoint(x: (sframe.width / 2 - wsize.width / 2) + sframe.origin.x, y: sframe.origin.y))
        }

        contentView?.superview?.alphaValue = 1
        wc.showWindow(nil)
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()

        endFader?.cancel()
        closer?.cancel()
        fader?.cancel()
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

    // MARK: Internal

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
    // MARK: Lifecycle

    public init(
        percentage: Binding<Float>,
        sliderWidth: CGFloat = 200,
        sliderHeight: CGFloat = 22,
        image: String? = nil,
        color: Color? = nil,
        backgroundColor: Color = .black.opacity(0.1),
        knobColor: Color? = nil,
        knobTextColor: Color? = nil,
        showValue: Binding<Bool>? = nil
    ) {
        _percentage = percentage
        _sliderWidth = sliderWidth.state
        _sliderHeight = sliderHeight.state
        _image = image.state
        _color = color.state
        _showValue = showValue ?? .constant(false)
        _backgroundColor = backgroundColor.state
        _knobColor = (knobColor ?? color ?? colors.accent).state
        _knobTextColor = (knobTextColor ?? ((color ?? colors.accent).textColor)).state
    }

    // MARK: Public

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
                        .frame(width: w * cgPercentage + sliderHeight / 2)
                    if let image = image {
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
                            .brightness(dragging ? -0.2 : 0)
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
                }
            }
            .frame(width: sliderWidth, height: sliderHeight)
            .cornerRadius(20)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !dragging { dragging = true }

                        self.percentage = cap(Float(value.location.x / geometry.size.width), minVal: 0, maxVal: 1)
                    }
                    .onEnded { value in
                        self.percentage = cap(Float(value.location.x / geometry.size.width), minVal: 0, maxVal: 1)
                        dragging = false
                    }
            )
            .animation(.easeOut(duration: 0.1), value: percentage)
            #if os(macOS)
                .onHover { hovering in
                    if hovering {
                        trackScrollWheel()
                    } else {
                        dragging = false
                        subs.forEach { $0.cancel() }
                        subs.removeAll()
                    }
                }
            #endif

        }.frame(width: sliderWidth, height: sliderHeight)
            .onChange(of: dragging) { tracking in
                AppleNativeControl.sliderTracking = tracking
                GammaControl.sliderTracking = tracking
                DDCControl.sliderTracking = tracking
            }
    }

    // MARK: Internal

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.colors) var colors

    @Binding var percentage: Float
    @State var sliderWidth: CGFloat = 200
    @State var sliderHeight: CGFloat = 22
    @State var image: String? = nil
    @State var color: Color? = nil
    @State var backgroundColor: Color = .black.opacity(0.1)
    @State var knobColor: Color? = nil
    @State var knobTextColor: Color? = nil
    @Binding var showValue: Bool

    @State var subs = Set<AnyCancellable>()
    @State var dragging = false

    #if os(macOS)
        func trackScrollWheel() {
            let pub = NSApp.publisher(for: \.currentEvent)
            pub
                .filter { event in event?.type == .scrollWheel }
                .throttle(
                    for: .milliseconds(20),
                    scheduler: DispatchQueue.main,
                    latest: true
                )
                .sink { event in
                    guard let event = event, event.deltaY == 0 else {
                        return
                    }

                    if !dragging { dragging = true }

                    let delta = Float(event.scrollingDeltaX) * (event.isDirectionInvertedFromDevice ? -1 : 1)
                    self.percentage = cap(self.percentage - (delta / 100), minVal: 0, maxVal: 1)
                }
                .store(in: &subs)
        }
    #endif
}

// MARK: - Colors

public struct Colors {
    // MARK: Lifecycle

    public init(_ colorScheme: SwiftUI.ColorScheme = .light, accent: Color) {
        self.accent = accent
        self.colorScheme = colorScheme
        bg = BG(colorScheme: colorScheme)
        fg = FG(colorScheme: colorScheme)
    }

    // MARK: Public

    public struct FG {
        // MARK: Public

        public var colorScheme: SwiftUI.ColorScheme

        public var isDark: Bool { colorScheme == .dark }
        public var isLight: Bool { colorScheme == .light }

        // MARK: Internal

        var gray: Color { isDark ? Colors.lightGray : Colors.darkGray }
        var primary: Color { isDark ? .white : .black }
    }

    public struct BG {
        // MARK: Public

        public var colorScheme: SwiftUI.ColorScheme

        public var isDark: Bool { colorScheme == .dark }
        public var isLight: Bool { colorScheme == .light }

        // MARK: Internal

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

    public static let xdr = Color(hue: 0.61, saturation: 0.26, brightness: 0.78)
    public static let subzero = Color(hue: 0.98, saturation: 0.56, brightness: 1.00)

    public var accent: Color
    public var colorScheme: SwiftUI.ColorScheme

    public var bg: BG
    public var fg: FG

    public var isDark: Bool { colorScheme == .dark }
    public var isLight: Bool { colorScheme == .light }
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
    @ObservedObject var display: Display

    var body: some View {
        VStack {
            let b = display.softwareBrightness
            let lb = display.lastSoftwareBrightness
            Text((b > 1 || (b == 1 && (lb > 1 || display.enhanced))) ? "XDR Brightness" : "Sub-zero brightness")
                .font(.system(size: 16, weight: .semibold, design: .monospaced))

            if display.enhanced {
                BigSurSlider(
                    percentage: $display.xdrBrightness,
                    image: "sun.max.circle.fill",
                    color: Colors.xdr.opacity(0.6),
                    backgroundColor: Colors.xdr.opacity(colorScheme == .dark ? 0.1 : 0.2),
                    knobColor: Colors.xdr,
                    showValue: .constant(true)
                )
            } else {
                BigSurSlider(
                    percentage: $display.softwareBrightness,
                    image: "moon.circle.fill",
                    color: Colors.subzero.opacity(0.6),
                    backgroundColor: Colors.subzero.opacity(colorScheme == .dark ? 0.1 : 0.2),
                    knobColor: Colors.subzero,
                    showValue: .constant(true)
                )
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
        .padding(.top, 20)
        .background(
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow, state: .active)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                    .shadow(color: Colors.blackMauve.opacity(0.2), radius: 8, x: 0, y: 4)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill((colorScheme == .dark ? Colors.blackMauve : Color.white).opacity(0.4))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }
        )
        .padding(10)
//        .opacity(display.lastSoftwareBrightness != display.softwareBrightness ? 1 : 0)
        .colors(colorScheme == .dark ? .dark : .light)
    }
}

let OSD_WIDTH: CGFloat = 300

// MARK: - BrightnessOSDView_Previews

struct BrightnessOSDView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            BrightnessOSDView(display: displayController.firstDisplay)
                .frame(maxWidth: OSD_WIDTH)
                .preferredColorScheme(.light)
            BrightnessOSDView(display: displayController.firstDisplay)
                .frame(maxWidth: OSD_WIDTH)
                .preferredColorScheme(.dark)
        }
    }
}

extension Display {
    func showSoftwareOSD() {
        mainAsync { [weak self] in
            guard let self = self else { return }
            if self.osdWindowController == nil {
                self.osdWindowController = OSDWindow(swiftuiView: AnyView(BrightnessOSDView(display: self)), display: self).wc
            }

            guard let osd = self.osdWindowController?.window as? OSDWindow else { return }

            osd.show()
        }
    }
}
