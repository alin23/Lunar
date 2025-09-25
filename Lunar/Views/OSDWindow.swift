import Carbon
import Cocoa
import Combine
import Defaults
import Foundation
import SwiftUI

func macOS26OSDPoint(screen: NSScreen?) -> NSPoint? {
    guard let screen else {
        return nil
    }
    let frame = screen.visibleFrame
    return NSPoint(x: frame.maxX - MAC26_OSD_WIDTH, y: frame.maxY - MAC26_OSD_HEIGHT - OSD_TIP_HEIGHT - OSD_TIP_SPACING - 10)
}

// MARK: - OSDWindow

final class OSDWindow: NSWindow, NSWindowDelegate {
    convenience init(swiftuiView: AnyView, display: Display, releaseWhenClosed: Bool, level: NSWindow.Level = NSWindow.Level(CGShieldingWindowLevel().i), ignoresMouseEvents: Bool = true) {
        self.init(contentRect: .zero, styleMask: .fullSizeContentView, backing: .buffered, defer: true, screen: display.nsScreen)
        self.display = display
        contentViewController = NSHostingController(rootView: swiftuiView)

        self.level = level
        collectionBehavior = [.stationary, .canJoinAllSpaces, .ignoresCycle, .fullScreenDisallowsTiling]
        shouldIgnoreMouseEvents = ignoresMouseEvents
        self.ignoresMouseEvents = ignoresMouseEvents
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

    var shouldIgnoreMouseEvents = false

    // Indicates whether the mouse cursor is currently inside this window's frame.
    // Used to delay fading/closing while the user is interacting or simply hovering.
    // Implemented using an NSTrackingArea attached to the content view.
    @objc dynamic var hovering = false

    weak var display: Display?
    lazy var wc = NSWindowController(window: self)

    var actionOnFade: (() -> Void)?

    var closer: DispatchWorkItem? { didSet { oldValue?.cancel() } }
    var fader: DispatchWorkItem? { didSet { oldValue?.cancel() } }
    var endFader: DispatchWorkItem? { didSet { oldValue?.cancel() } }

    override func mouseEntered(with event: NSEvent) {
        hovering = true
        super.mouseEntered(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        hovering = false
        super.mouseExited(with: event)
    }

    func hide() {
        fader = nil
        endFader = nil
        closer = nil
        removeHoverTrackingArea()

        if let v = contentView?.superview {
            v.alphaValue = 0.0
        }
        close()
        windowController?.close()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard isReleasedWhenClosed else { return true }
        windowController?.window = nil
        windowController = nil
        return true
    }

    func show(
        at point: NSPoint? = nil,
        closeAfter closeMilliseconds: Int = 3050,
        fadeAfter fadeMilliseconds: Int = 2000,
        verticalOffset: CGFloat? = nil,
        possibleWidth: CGFloat = 0
    ) {
        guard let screen = display?.nsScreen else { return }
//        let alreadyVisible = isVisible && contentView?.superview?.alphaValue == 1

        if let point {
            setFrame(NSRect(origin: point, size: frame.size), display: true)
        } else {
            let wsize = frame.size
            let sframe = screen.frame
            let point = CGPoint(
                x: (sframe.width / 2 - (wsize.width ?! possibleWidth) / 2) + sframe.origin.x,
                y: sframe.origin.y + (verticalOffset ?? CachedDefaults[.customOSDVerticalOffset].cg)
            )
            setFrame(NSRect(origin: point, size: wsize), display: wsize.width > 1)
            if wsize.width <= 1 {
                mainAsyncAfter(ms: 1) { [weak self] in
                    guard let wsize = self?.frame.size else { return }
                    let sframe = screen.frame
                    let point = CGPoint(
                        x: (sframe.width / 2 - wsize.width / 2) + sframe.origin.x,
                        y: sframe.origin.y + (verticalOffset ?? CachedDefaults[.customOSDVerticalOffset].cg)
                    )
                    self?.setFrame(NSRect(origin: point, size: wsize), display: true)
                }
            }
        }

        ignoresMouseEvents = shouldIgnoreMouseEvents
        contentView?.superview?.alphaValue = 1
        if canBecomeKey {
            wc.showWindow(nil)
            makeKeyAndOrderFront(nil)
        }
        orderFrontRegardless()
        addHoverTrackingArea()

        endFader = nil
        closer = nil
        fader = nil

        guard closeMilliseconds > 0 else { return }
        actionOnFade = { [weak self] in
            guard let s = self, s.isVisible else { return }
            guard !s.hovering else {
                self?.fader = mainAsyncAfter(ms: fadeMilliseconds) { self?.actionOnFade?() }
                return
            }
            s.ignoresMouseEvents = true
            s.contentView?.superview?.transition(1)
            s.contentView?.superview?.alphaValue = 0.01
            s.endFader = mainAsyncAfter(ms: 1000) { [weak self] in
                self?.contentView?.superview?.alphaValue = 0
            }
            s.closer = mainAsyncAfter(ms: closeMilliseconds) { [weak self] in
                self?.close()
            }
        }
        fader = mainAsyncAfter(ms: fadeMilliseconds) { [weak self] in
            self?.actionOnFade?()
        }
    }

    func windowWillClose(_ notification: Notification) {
        removeHoverTrackingArea()
    }

    // Tracking area for mouse enter/exit.
    private var hoverTrackingArea: NSTrackingArea?

    // MARK: - Hover Tracking

    // MARK: - Tracking Area based hover detection

    private func addHoverTrackingArea() {
        guard let view = contentView else { return }
        removeHoverTrackingArea()
        let opts: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .activeAlways,
            .inVisibleRect,
        ]
        let area = NSTrackingArea(rect: view.bounds, options: opts, owner: self, userInfo: nil)
        view.addTrackingArea(area)
        hoverTrackingArea = area
    }

    private func removeHoverTrackingArea() {
        if let area = hoverTrackingArea, let view = contentView {
            view.removeTrackingArea(area)
        }
        hoverTrackingArea = nil
        hovering = false
    }

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

struct BigSurSlider: View {
    init(
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
        shownValue: Binding<Double?>? = nil,
        acceptsMouseEvents: Binding<Bool>? = nil,
        disabled: Binding<Bool>? = nil,
        enableText: String? = nil,
        mark: Binding<Float>? = nil,
        beforeSettingPercentage: ((Float) -> Void)? = nil,
        onSettingPercentage: ((Float) -> Void)? = nil,
        insideText: (() -> AnyView)? = nil
    ) {
        _knobColor = .constant(knobColor)
        _knobTextColor = .constant(knobTextColor)

        _percentage = percentage
        _image = imageBinding ?? .constant(image)
        _color = colorBinding ?? .constant(color)
        _showValue = showValue ?? .constant(false)
        _shownValue = shownValue ?? .constant(nil)
        _backgroundColor = backgroundColorBinding ?? .constant(backgroundColor)
        _acceptsMouseEvents = acceptsMouseEvents ?? .constant(true)
        _disabled = disabled ?? .constant(false)
        _enableText = State(initialValue: enableText)
        _mark = mark ?? .constant(0)

        _knobColor = knobColorBinding ?? colorBinding ?? .constant(knobColor ?? Color.peach)
        _knobTextColor = knobTextColorBinding ?? .constant(knobTextColor ?? ((color ?? Color.peach).textColor))

        self.sliderWidth = sliderWidth
        self.sliderHeight = sliderHeight
        self.beforeSettingPercentage = beforeSettingPercentage
        self.onSettingPercentage = onSettingPercentage
        self.insideText = insideText?()
    }

    @Environment(\.colorScheme) var colorScheme

    @EnvironmentObject var env: EnvState

    @Binding var percentage: Float
    @Binding var image: String?
    @Binding var color: Color?
    @Binding var backgroundColor: Color
    @Binding var knobColor: Color?
    @Binding var knobTextColor: Color?
    @Binding var showValue: Bool
    @Binding var shownValue: Double?

    @State var scrollWheelListener: Cancellable?

    @State var hovering = false
    @State var enableText: String? = nil
    @State var lastCursorPosition = NSEvent.mouseLocation
    @Binding var acceptsMouseEvents: Bool
    @Binding var disabled: Bool
    @Binding var mark: Float

    @State var clickedKnob = false

    var insideText: AnyView?

    var beforeSettingPercentage: ((Float) -> Void)?
    var onSettingPercentage: ((Float) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width - sliderHeight
            let cgPercentage = cap(percentage, minVal: 0, maxVal: 1).cg

            ZStack(alignment: .leading) {
                Rectangle()
                    .foregroundColor(backgroundColor)
                ZStack(alignment: .leading) {
                    Rectangle()
                        .foregroundColor(color ?? Color.peach)
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

                    // knob(cgPercentage: cgPercentage)
                    //     .offset(x: cgPercentage * w, y: 0)

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
                        color: Color.red.opacity(0.7),
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

                        beforeSettingPercentage?(percentage)
                        let x = value.location.x
                        let w = geometry.size.width
                        let h = sliderHeight / 2
                        percentage = Float(x.map(from: (h, w - h), to: (0, 1))).capped(between: 0, and: 1)
                        onSettingPercentage?(percentage)
                    }
                    .onEnded { value in
                        guard acceptsMouseEvents, !disabled else { return }
                        draggingSliderSetter = nil
                        beforeSettingPercentage?(percentage)
                        let x = value.location.x
                        let w = geometry.size.width
                        let h = sliderHeight / 2
                        percentage = Float(x.map(from: (h, w - h), to: (0, 1))).capped(between: 0, and: 1)
                        onSettingPercentage?(percentage)
                        env.draggingSlider = false
                    }
            )
            .onHover { hov in
                withAnimation { hovering = hov }
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
            .overlay(knob(cgPercentage: cgPercentage).offset(x: (cgPercentage - 0.5) * w, y: 0), alignment: .center)
        }
        .frame(width: sliderWidth, height: sliderHeight)
        .onChange(of: env.draggingSlider) { tracking in
            AppleNativeControl.sliderTracking = tracking || hovering
            GammaControl.sliderTracking = tracking || hovering
            DDCControl.sliderTracking = tracking || hovering
            withAnimation(.easeIn(duration: 0.2)) {
                clickedKnob = tracking && hovering
            }
        }
        .onChange(of: hovering) { tracking in
            AppleNativeControl.sliderTracking = tracking || env.draggingSlider
            GammaControl.sliderTracking = tracking || env.draggingSlider
            DDCControl.sliderTracking = tracking || env.draggingSlider
            withAnimation(.easeIn(duration: 0.2)) {
                clickedKnob = tracking && env.draggingSlider
            }
        }
    }

    private var sliderWidth: CGFloat = 200
    private var sliderHeight: CGFloat = 22

    @ViewBuilder private func knob(cgPercentage: CGFloat) -> some View {
        ZStack {
            if showValue, let insideText {
                insideText
                    .offset(x: (sliderHeight + 2) * (cgPercentage < 0.25 ? 1 : -1))
                    .opacity(hovering ? 1 : 0)
            }
            Circle()
                .foregroundColor(knobColor)
                .shadow(color: Color.black.opacity((percentage > 0.3 ? 0.3 : percentage.d) * (clickedKnob ? 1 : 0.3)), radius: clickedKnob ? 6 : 4, x: -1, y: clickedKnob ? 2 : 0)
                .frame(width: sliderHeight, height: sliderHeight, alignment: .center)
                .brightness(clickedKnob ? 0.05 : 0)
            if showValue {
                Text((shownValue?.f ?? (percentage * 100)).str(decimals: 0))
                    .foregroundColor(knobTextColor)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .allowsHitTesting(false)
            }
        }.allowsHitTesting(false)
    }

    private func trackScrollWheel() {
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
                beforeSettingPercentage?(percentage)
                percentage = cap(percentage - (delta / 100), minVal: 0, maxVal: 1)
                onSettingPercentage?(percentage)
            }
    }
}

extension NSEvent.Phase {
    var str: String {
        switch self {
        case .mayBegin: "mayBegin"
        case .began: "began"
        case .changed: "changed"
        case .stationary: "stationary"
        case .cancelled: "cancelled"
        case .ended: "ended"
        default:
            "phase(\(rawValue))"
        }
    }
}

var hoveringSliderSetter: DispatchWorkItem? {
    didSet { oldValue?.cancel() }
}

var draggingSliderSetter: DispatchWorkItem? {
    didSet { oldValue?.cancel() }
}
struct CheckerView: View {
    var white: Int
    var squareSize: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(white)")
                .font(.system(size: squareSize / 2, weight: .semibold, design: .rounded))
                .foregroundColor(.black)

            row(reversed: true)
            row()
            row(reversed: true)
            row()
        }
    }

    func row(reversed: Bool = false) -> some View {
        let gray = Color(white: white.d / 255)
        return HStack(spacing: 0) {
            Rectangle()
                .fill(reversed ? gray : .clear)
                .frame(width: squareSize, height: squareSize)
            Rectangle()
                .fill(reversed ? .clear : gray)
                .frame(width: squareSize, height: squareSize)
            Rectangle()
                .fill(reversed ? gray : .clear)
                .frame(width: squareSize, height: squareSize)
            Rectangle()
                .fill(reversed ? .clear : gray)
                .frame(width: squareSize, height: squareSize)
        }.fixedSize()
    }

}

enum ArrangementManagerState {
    case started
    case cancelled
    case committed
}

final class ArrangementManager: ObservableObject {
    init() {}

    @Published var idsToRearrange: [CGDirectDisplayID] = []
    @Published var idsOrderedLeftToRight: [CGDirectDisplayID] = []
    var localMonitor: Any?
    var globalMonitor: Any?

    @Published var state: ArrangementManagerState = .started {
        didSet {
            switch state {
            case .started:
                return
            case .cancelled:
                timeoutTask = nil
                hideOSD()
            case .committed:
                timeoutTask = nil
                rearrange()
                hideOSD()
            }
        }
    }

    var timeoutTask: DispatchWorkItem? {
        didSet { oldValue?.cancel() }
    }

    func hideOSD() {
        DC.activeDisplayList.forEach { $0.hideArrangementOSD() }
    }

    @available(iOS 16, macOS 13, *)
    @discardableResult
    func wait() async throws -> Bool? {
        for _ in 1 ... 100 {
            if state != .started {
                return state == .committed
            }
            if Set(idsOrderedLeftToRight) == Set(idsToRearrange) {
                return true
            }
            try await Task.sleep(for: .milliseconds(100))
        }

        state = .cancelled
        return false
    }

    func rearrange() {
        guard !idsOrderedLeftToRight.isEmpty else { return }

        let boundsByID = idsOrderedLeftToRight.map { id in
            (id, CGDisplayBounds(id))
        }
        var x = boundsByID.map(\.1).min(by: \.minX)!.minX

        Display.configure { config in
            for (id, bounds) in boundsByID {
                CGConfigureDisplayOrigin(config, id, Int32(x.rounded()), Int32(bounds.minY.rounded()))
                x += bounds.width
            }

            return true
        }

        notify(
            identifier: "fyi.lunar.Lunar.Shortcuts",
            title: "Arranged monitors",
            body: "The monitor arrangement was fixed."
        )
    }

    func pressedID(withIndex index: Int, event: NSEvent) -> NSEvent? {
        guard index <= idsToRearrange.count, index > 0, let id = idsToRearrange[safe: index - 1] else {
            return event
        }

        if idsOrderedLeftToRight.contains(id) {
            idsOrderedLeftToRight = idsOrderedLeftToRight.without(id)
        } else {
            idsOrderedLeftToRight = idsOrderedLeftToRight + [id]
        }

        if Set(idsOrderedLeftToRight) == Set(idsToRearrange) {
            mainAsyncAfter(ms: 500) {
                self.state = .committed
            }
        }
        return nil
    }

    @discardableResult
    func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard state == .started else {
            return event
        }

        switch event.keyCode.i {
        case kVK_Escape:
            state = .cancelled
        case kVK_Return:
            state = .committed
        case kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9:
            return pressedID(withIndex: KeyEventHandling.NUMBER_KEYS.firstIndex(of: event.keyCode.i)!, event: event)
        default:
            return event
        }
        return nil
    }

    func start(_ ids: [CGDirectDisplayID]) {
        idsToRearrange = ids
        idsOrderedLeftToRight = []
        state = .started

        if Defaults[.accessibilityPermissionsGranted], globalMonitor == nil {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { event in
                self.handleKeyEvent(event)
            }
        }
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                self.handleKeyEvent(event)
            }
        }
        timeoutTask = mainAsyncAfter(ms: 30000) {
            if self.state == .started {
                self.state = .cancelled
            }
        }
    }
}

let AM = ArrangementManager()

struct ArrangementOSDView: View {
    @Environment(\.colorScheme) var colorScheme

    @ObservedObject var am = AM
    @State var displayID: CGDirectDisplayID
    @State var number: Int

    var body: some View {
        let selected = am.idsOrderedLeftToRight.contains(displayID)
        ZStack {
            Text(number.s).font(.system(size: 60, weight: .black, design: .monospaced))
                .foregroundColor(selected ? Color.blackMauve : .primary.opacity(0.75))
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 30)
        .background(
            ZStack {
                VisualEffectBlur(material: .osd, blendingMode: .behindWindow, state: .active)
                if selected {
                    Color.peach.opacity(0.8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
        .frame(width: NATIVE_OSD_WIDTH, height: NATIVE_OSD_WIDTH, alignment: .center)
        .fixedSize()
    }
}

let OSD_TIP_HEIGHT: CGFloat = 24
let OSD_TIP_SPACING: CGFloat = 16

@available(macOS 26.0, *)
struct CustomGlassEffectView<Content: View>: NSViewRepresentable {
    init(
        variant: Int? = nil,
        scrimState: Int? = nil,
        subduedState: Int? = nil,
        interactionState: Int? = nil,
        contentLensing: Int? = nil,
        adaptiveAppearance: Int? = nil,
        useReducedShadowRadius: Int? = nil,
        style: NSGlassEffectView.Style? = nil,
        tint: NSColor? = nil,
        cornerRadius: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.variant = variant
        self.scrimState = scrimState
        self.subduedState = subduedState
        self.interactionState = interactionState
        self.contentLensing = contentLensing
        self.adaptiveAppearance = adaptiveAppearance
        self.useReducedShadowRadius = useReducedShadowRadius
        self.style = style
        self.tint = tint
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    func makeNSView(context _: Context) -> NSView {
        guard let nsGlassEffectViewType = NSClassFromString("NSGlassEffectView") as? NSView.Type else {
            return NSView()
        }
        let nsView = nsGlassEffectViewType.init(frame: .zero)
        configureView(nsView)
        let hosting = NSHostingView(rootView: content)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        nsView.setValue(hosting, forKey: "contentView")
        return nsView
    }

    func updateNSView(_ nsView: NSView, context _: Context) {
        if let hosting = nsView.value(forKey: "contentView") as? NSHostingView<Content> { hosting.rootView = content }
        configureView(nsView)
    }

    func configureView(_ nsView: NSView) {
        if let variant { nsView.setValue(variant, forKey: "_variant") }
        if let interactionState { nsView.setValue(interactionState, forKey: "_interactionState") }
        if let contentLensing { nsView.setValue(contentLensing, forKey: "_contentLensing") }
        if let adaptiveAppearance { nsView.setValue(adaptiveAppearance, forKey: "_adaptiveAppearance") }
        if let useReducedShadowRadius { nsView.setValue(useReducedShadowRadius, forKey: "_useReducedShadowRadius") }
        if let scrimState { nsView.setValue(scrimState, forKey: "_scrimState") }
        if let subduedState { nsView.setValue(subduedState, forKey: "_subduedState") }
        if let style { (nsView as? NSGlassEffectView)?.style = style }
        if let tint { nsView.setValue(tint, forKey: "tintColor") }
        if let cornerRadius { nsView.setValue(cornerRadius, forKey: "cornerRadius") }
    }

    private let variant: Int? // 0 - 19
    private let scrimState: Int? // Scrim overlay (0 = off, 1 = on)
    private let subduedState: Int? // Subdued state (0 = normal, 1 = subdued)
    private let interactionState: Int? // set to 1, combined with variant 13 allows for clear glass compositor filter
    private let contentLensing: Int?
    private let adaptiveAppearance: Int?
    private let useReducedShadowRadius: Int?
    private let style: NSGlassEffectView.Style?
    private let tint: NSColor?
    private let cornerRadius: CGFloat?
    private let content: Content

}

@available(macOS 26, *)
struct Mac26BrightnessOSDView: View {
    static let VERTICAL_PADDING: CGFloat = 6
    static let HORIZONTAL_PADDING: CGFloat = 20

    @Environment(\.colorScheme) var colorScheme

    @ObservedObject var osd: OSDState

    let STEPS: [Float] = stride(from: 0.0, through: 1.0, by: 0.0625).map { $0 }

    var value: CGFloat {
        let v = osd.value.map(from: (0, 1), to: (0, 160))
        if v.remainderDistance(16) < 0.13 {
            return ((v / 16).rounded() * 16).cg
        }
        return v.cg
    }

    var body: some View {
        VStack(spacing: OSD_TIP_SPACING) {
            CustomGlassEffectView(variant: 6, scrimState: 0, subduedState: 0, tint: osd.color?.opacity(0.2).ns ?? .clear, cornerRadius: 24) {
                square.animation(.fastSpring, value: osd.tip)
                    .frame(width: MAC26_OSD_WIDTH, height: MAC26_OSD_HEIGHT)
            }
            .brightness(-0.3)
            .background(Material.ultraThin.materialActiveAppearance(.active).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            tip.transition(.scale.animation(.fastSpring))
        }
        .preferredColorScheme(.dark)
        .frame(alignment: .center)
        .onHover { hovering in
            osd.hovering = hovering
        }
    }

    @ViewBuilder var tip: some View {
        (osd.tip ?? Text("TIP"))
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .frame(height: OSD_TIP_HEIGHT)
            .background(
                VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow, state: .active)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            )
            .fixedSize()
            .opacity(osd.tip == nil ? 0 : 1)
    }

    @State var variant = 0

    var slider: some View {
        SwiftUI.Slider(value: $osd.value) {} ticks: {
            SliderTickContentForEach(STEPS, id: \.self) { value in
                SliderTick(value)
            }
        }
        .tint(.white)
        .brightness(2.0)
        .onChange(of: osd.value) { newValue in
            osd.onChange?(newValue)
        }
        .disabled(osd.locked)
    }

    var square: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(osd.textLeft)
                    .font(.system(size: 12, weight: .medium))
                    .brightness(0.5)
                Spacer()
                Text(osd.text.isEmpty ? "\((osd.value * 100).intround)%" : osd.text)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .brightness(0.5)
                if osd.locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .brightness(0.5)
                }
            }
            HStack {
                Image(systemName: osd.imageLeft)
                    .opacity(osd.imageLeft == "clear" ? 0 : 1)
                    .foregroundStyle(.white.opacity(0.8))
                    .brightness(0.5)
                slider
                Image(systemName: osd.image)
                    .brightness(0.5)
            }
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(.white)

        }
        .padding(.horizontal, Self.HORIZONTAL_PADDING)
        .padding(.vertical, Self.VERTICAL_PADDING)
        .frame(width: MAC26_OSD_WIDTH, height: MAC26_OSD_HEIGHT, alignment: .center)
        .fixedSize()
    }

}

struct BrightnessOSDView: View {
    @Environment(\.colorScheme) var colorScheme

    @ObservedObject var osd: OSDState

    var value: CGFloat {
        let v = osd.value.map(from: (0, 1), to: (0, 160))
        if v.remainderDistance(16) < 0.13 {
            return ((v / 16).rounded() * 16).cg
        }
        return v.cg
    }

    var body: some View {
        VStack(spacing: OSD_TIP_SPACING) {
            square.animation(.fastSpring, value: osd.tip)
            tip.transition(.scale.animation(.fastSpring))
        }.frame(alignment: .center)
    }

    @ViewBuilder var tip: some View {
        (osd.tip ?? Text("TIP"))
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.primary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .frame(height: OSD_TIP_HEIGHT)
            .background(
                VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow, state: .active)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            )
            .fixedSize()
            .opacity(osd.tip == nil ? 0 : 1)
    }

    var square: some View {
        ZStack {
            VStack {
                Image(systemName: osd.image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: NATIVE_OSD_WIDTH * 0.42, height: NATIVE_OSD_WIDTH * 0.42)
                    .font(.system(size: 48, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(NATIVE_OSD_WIDTH * 0.05)

                Text(osd.text).font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary.opacity(0.75))
            }

            if osd.locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .offset(y: NATIVE_OSD_WIDTH * 0.4)
            } else {
                chiclets
                    .offset(y: NATIVE_OSD_WIDTH * 0.78)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
        .padding(.top, 20)
        .background(
            VisualEffectBlur(material: .osd, blendingMode: .behindWindow, state: .active)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .frame(width: NATIVE_OSD_WIDTH, height: NATIVE_OSD_WIDTH, alignment: .center)
                .fixedSize()
        )
        .frame(width: NATIVE_OSD_WIDTH, height: NATIVE_OSD_WIDTH, alignment: .center)
        .fixedSize()
        .padding(.horizontal, 100)
    }

    var chiclets: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 0.0, y: 0))
                path.addLine(to: CGPoint(x: 161, y: 0))
            }
            .stroke(style: StrokeStyle(lineWidth: 8))
            .foregroundColor(Color.black)

            Path { path in
                path.move(to: CGPoint(x: 1, y: 0))
                path.addLine(to: CGPoint(x: value, y: 0))
            }
            .stroke(.black, style: StrokeStyle(lineWidth: 6, dash: [9, 1]))
            .blendMode(.destinationOut)

            if let color = osd.color ?? (colorScheme == .dark ? .primary.opacity(0.75) : nil) {
                color
                    .clipShape(
                        Path { path in
                            path.move(to: CGPoint(x: 1, y: 0))
                            path.addLine(to: CGPoint(x: value, y: 0))
                        }
                        .stroke(style: StrokeStyle(lineWidth: 6, dash: [9, 1]))
                    )
                    .shadow(color: osd.glowRadius == 0 ? .clear : (osd.color ?? .clear), radius: osd.value.cg * osd.glowRadius, x: 0, y: 0)
                    .animation(.easeOut(duration: 0.15), value: osd.value)
            }
        }
        .compositingGroup()
    }
}

#Preview {
    let osdState = OSDState()
    osdState.value = 0.5
    osdState.locked = true
    osdState.text = "320 nits"
    osdState.textLeft = "Built-in"
    osdState.imageLeft = "sun.min.fill"
    osdState.image = "sun.max.fill"
    osdState.tip = Text("\(Image(systemName: "sun.max.fill")) Double press Brightness Up to unlock 1600 nits")
    if #available(macOS 26, *) {
        return Mac26BrightnessOSDView(osd: osdState).padding()
    } else {
        return BrightnessOSDView(osd: osdState).padding()
    }
}

// MARK: - AutoOSDView

struct AutoOSDView: View {
    @Environment(\.colorScheme) var colorScheme

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
                    .shadow(color: Color.blackMauve.opacity(0.2), radius: 8, x: 0, y: 4)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill((colorScheme == .dark ? Color.blackMauve : Color.white).opacity(0.4))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
            }
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 30)
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
let MAC26_OSD_WIDTH: CGFloat = 290
let MAC26_OSD_HEIGHT: CGFloat = 62
let OSD_WIDTH: CGFloat = 300

// MARK: - OSDState

final class OSDState: ObservableObject {
    @Published var image = "sun.max"
    @Published var imageLeft = "sun.min"
    @Published var value: Float = 1.0
    @Published var text = ""
    @Published var textLeft = ""
    @Published var color: Color? = nil
    @Published var glowRadius: CGFloat = 5
    @Published var tip: Text? = nil
    @Published var locked = false
    @Published var hovering = false
    var onChange: ((Float) -> Void)? = nil
}

extension Display {
    func hideSoftwareOSD() {
        softwareOSDTask = mainAsync { [weak self] in
            guard let osd = self?.osdWindowController?.window as? OSDWindow else { return }
            osd.hide()
            self?.osdState.tip = nil
            self?.osdState.onChange = nil
            self?.osdWindowController = nil
        }
    }

    func showSoftwareOSD(image: String, value: Float, text: String, color: Color?, glowRadius: CGFloat = 5, locked: Bool = false, textLeft: String = "", imageLeft: String = "clear", onChange: ((Float) -> Void)? = nil) {
        guard !isAllDisplays, !isForTesting, !CachedDefaults[.hideOSD] else { return }
        softwareOSDTask = mainAsync { [weak self] in
            guard let self else { return }

            osdState.image = image
            osdState.value = value
            osdState.text = text
            osdState.color = color
            osdState.glowRadius = glowRadius
            osdState.locked = locked

            osdState.textLeft = textLeft
            osdState.imageLeft = imageLeft
            osdState.onChange = onChange

            if osdWindowController == nil {
                let ignoresMouseEvents = if #available(macOS 26, *) {
                    false
                } else {
                    true
                }
                let view = if #available(macOS 26, *) {
                    AnyView(Mac26BrightnessOSDView(osd: osdState))
                } else {
                    AnyView(BrightnessOSDView(osd: osdState))
                }

                osdWindowController = OSDWindow(
                    swiftuiView: view,
                    display: self,
                    releaseWhenClosed: false,
                    ignoresMouseEvents: ignoresMouseEvents
                ).wc
            }

            guard let osd = osdWindowController?.window as? OSDWindow else { return }

            if #available(macOS 26, *) {
                osd.show(at: macOS26OSDPoint(screen: nsScreen), possibleWidth: MAC26_OSD_WIDTH)
            } else {
                osd.show(verticalOffset: 100, possibleWidth: NATIVE_OSD_WIDTH * 2)
            }
        }
    }

    func hideArrangementOSD() {
        mainAsync { [weak self] in
            guard let osd = self?.arrangementOsdWindowController?.window as? OSDWindow else { return }
            osd.hide()
            self?.arrangementOsdWindowController = nil
        }
    }

    func showArrangementOSD(id: CGDirectDisplayID, number: Int) {
        guard !isAllDisplays, !isForTesting else { return }
        mainAsync { [weak self] in
            guard let self else { return }

            if arrangementOsdWindowController == nil {
                let view = ArrangementOSDView(displayID: id, number: number)
                arrangementOsdWindowController = OSDWindow(
                    swiftuiView: AnyView(view),
                    display: self,
                    releaseWhenClosed: false
                ).wc
            }

            guard let osd = arrangementOsdWindowController?.window as? OSDWindow else { return }

            osd.show(closeAfter: 0, fadeAfter: 0, verticalOffset: 140, possibleWidth: NATIVE_OSD_WIDTH * 2)
        }
    }

    func showAutoBlackOutOSD() {
        mainAsync { [weak self] in
            guard let self, !self.blackOutEnabled else {
                self?.autoOsdWindowController?.close()
                return
            }
            autoOsdWindowController?.close()
            autoOsdWindowController = OSDWindow(
                swiftuiView: AnyView(
                    AutoOSDView(
                        display: self,
                        done: .oneway { [weak self] in self?.blackOutEnabled ?? true },
                        title: "Turning off",
                        subtitle: name,
                        color: Color.red,
                        icon: "power.circle.fill"
                    )
                    .environmentObject(EnvState())
                ),
                display: self, releaseWhenClosed: true
            ).wc

            guard let osd = autoOsdWindowController?.window as? OSDWindow else { return }

            osd.show(closeAfter: 1000, fadeAfter: ((AUTO_OSD_DEBOUNCE_SECONDS + 0.5) * 1000).i, possibleWidth: NATIVE_OSD_WIDTH * 2)
        }
    }

    func showAutoXdrOSD(xdrEnabled: Bool, reason: String) {
        mainAsync { [weak self] in
            guard let self else { return }

            autoOsdWindowController?.close()
            autoOsdWindowController = OSDWindow(
                swiftuiView: AnyView(
                    AutoOSDView(
                        display: self,
                        done: .oneway { [weak self] in (self?.enhanced ?? xdrEnabled) == xdrEnabled },
                        title: xdrEnabled ? "Activating XDR" : "Disabling XDR",
                        subtitle: reason,
                        color: Color.xdr,
                        icon: "sun.max.circle.fill"
                    )
                    .environmentObject(EnvState())
                ),
                display: self, releaseWhenClosed: true
            ).wc

            guard let osd = autoOsdWindowController?.window as? OSDWindow else { return }

            osd.show(closeAfter: 1000, fadeAfter: ((AUTO_OSD_DEBOUNCE_SECONDS + 0.5) * 1000).i)
        }
    }
}

import Cocoa
import Foundation
import SwiftUI

// MARK: - PanelWindow

final class PanelWindow: NSPanel {
    convenience init(swiftuiView: AnyView, level: NSWindow.Level = .floating) {
        self.init(contentViewController: NSHostingController(rootView: swiftuiView))

        self.level = level
        setAccessibilityRole(.popover)
        setAccessibilitySubrole(.unknown)

        backgroundColor = .clear
        contentView?.bg = .clear
        contentView?.layer?.masksToBounds = false
        isOpaque = false
        hasShadow = false
        styleMask = [.fullSizeContentView, .nonactivatingPanel]
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
    }

    override var canBecomeKey: Bool { shouldBecomeKey }

    var shouldBecomeKey = false {
        didSet {
            if shouldBecomeKey, !oldValue {
                NSApp.activate(ignoringOtherApps: true)
                makeKeyAndOrderFront(nil)
            }
        }
    }

    @objc func hasActiveAppearance() -> Bool {
        true
    }

    func forceClose() {
        wc.close()
        wc.window = nil
        close()
    }

    func show(at point: NSPoint? = nil, animate: Bool = false) {
        if let point {
            #if arch(arm64)
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
            #else
                setFrameOrigin(point)
            #endif
        } else {
            center()
        }

        guard !isVisible else { return }

        if canBecomeKey {
            wc.showWindow(nil)
            makeKeyAndOrderFront(nil)
        }
        orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    private lazy var wc = NSWindowController(window: self)
}
