import Cocoa
import Foundation

// MARK: - SliderCell

class SliderCell: NSSliderCell {
    // MARK: Lifecycle

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    // MARK: Internal

    @Atomic var pressed = false

    @IBInspectable dynamic var fillOrigin: CGFloat = 0
    @IBInspectable dynamic var knobImage: NSImage? = nil
    @IBInspectable dynamic var imageOpacity: CGFloat = 1.0
    @IBInspectable dynamic var verticalPadding: CGFloat = 10
    @IBInspectable dynamic var cornerRadius: CGFloat = 4
    @IBInspectable dynamic var drawText = true
    @IBInspectable dynamic var borderOpacity: CGFloat = 0.02
    @IBInspectable dynamic var bgOpacity: CGFloat = 0.3

    var shouldDrawText: Bool {
        drawText
    }

    @IBInspectable dynamic var color = NSColor(named: "Slider")! {
        didSet { controlView?.needsDisplay = true }
    }

    @IBInspectable dynamic var knobColor = NSColor.white {
        didSet { controlView?.needsDisplay = true }
    }

    override func startTracking(at startPoint: NSPoint, in controlView: NSView) -> Bool {
        pressed = true
        AppleNativeControl.sliderTracking = true
        GammaControl.sliderTracking = true
        DDCControl.sliderTracking = true
        return super.startTracking(at: startPoint, in: controlView)
    }

    override func stopTracking(last lastPoint: NSPoint, current stopPoint: NSPoint, in controlView: NSView, mouseIsUp flag: Bool) {
        pressed = false
        AppleNativeControl.sliderTracking = false
        GammaControl.sliderTracking = false
        DDCControl.sliderTracking = false
        super.stopTracking(last: lastPoint, current: stopPoint, in: controlView, mouseIsUp: flag)
    }

    override func drawKnob(_ knobRect: NSRect) {
        let size = verticalPadding
        let rect = NSRect(x: knobRect.midX - (size / 2) + 0.5, y: knobRect.midY - (size / 2) - 1.5, width: size - 1, height: size - 1)
        let value = (minValue == 0 && maxValue == 1) ? CGFloat(floatValue) : CGFloat(mapNumber(
            doubleValue,
            fromLow: minValue,
            fromHigh: maxValue,
            toLow: 0.0,
            toHigh: 1.0
        ))

        // Stolen from @waydabber: https://github.com/MonitorControl/MonitorControl/blob/1f595ff1df40b65c77d26a91a7f0de231eabb921/MonitorControl/Support/SliderHandler.swift#L111-L117
        let knobShadowAlpha = 0.03 * CGFloat(
            cap((value - 0.08) * 5, minVal: 0, maxVal: 1)
        )
        let knobShadow1 = NSBezierPath(ovalIn: rect.offsetBy(dx: -2, dy: 0))
        blackMauve.withAlphaComponent(knobShadowAlpha).setFill()
        knobShadow1.fill()
        let knobShadow2 = NSBezierPath(ovalIn: rect.offsetBy(dx: -4, dy: 0))
        blackMauve.withAlphaComponent(knobShadowAlpha).setFill()
        knobShadow2.fill()
        let knobShadow3 = NSBezierPath(ovalIn: rect.offsetBy(dx: -6, dy: 0))
        blackMauve.withAlphaComponent(knobShadowAlpha).setFill()
        knobShadow3.fill()

        let knob = NSBezierPath(ovalIn: rect)
        let color = knobColor.withSystemEffect(pressed ? .pressed : .none)
        color.setFill()
        knob.fill()

        if shouldDrawText {
            let centered = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
            centered.alignment = .center

            let font = NSFont.monospacedSystemFont(ofSize: 8, weight: .semibold)
            let textHeight = font.boundingRectForFont.height
            let textRect = NSRect(x: rect.minX, y: rect.midY - (textHeight / 2) + 1, width: rect.width, height: textHeight)

            let value = (minValue == 0 && maxValue == 1) ? CGFloat(floatValue * 100) : CGFloat(floatValue.intround)

            value.str(decimals: 0)
                .withFont(font)
                .withTextColor(knobColor.hsb.2 > 70 ? .black : .white)
                .withParagraphStyle(centered)
                .draw(in: textRect)
        }

        guard let knobImage = knobImage else {
            return
        }

        let imageSize = size * 0.6
        let imageRect = NSRect(
            x: knobRect.midX - (imageSize / 2),
            y: knobRect.midY - (imageSize / 2) - 2,
            width: imageSize,
            height: imageSize
        )
        knobImage.draw(
            in: imageRect,
            from: .zero,
            operation: .sourceOver,
            fraction: imageOpacity
        )
    }

    override func barRect(flipped: Bool) -> NSRect {
        let bar = super.barRect(flipped: flipped)
        let knob = knobRect(flipped: flipped)

        let height = max(verticalPadding, knob.height)
        let rect = NSRect(x: bar.origin.x, y: knob.origin.y - 2, width: bar.width, height: height)

        return rect
    }

    override func drawBar(inside aRect: NSRect, flipped _: Bool) {
        let rect = NSRect(x: aRect.origin.x, y: aRect.midY - (verticalPadding / 2), width: aRect.width, height: verticalPadding)

        let bg = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        let color = isEnabled ? color : (color.blended(withFraction: 0.5, of: .gray) ?? .gray)
        color.withAlphaComponent(bgOpacity).setFill()
        bg.fill()
        sliderBorderColor.withAlphaComponent(borderOpacity).setStroke()
        bg.stroke()

        let value = (minValue == 0 && maxValue == 1) ? CGFloat(floatValue) : CGFloat(mapNumber(
            doubleValue,
            fromLow: minValue,
            fromHigh: maxValue,
            toLow: 0.0,
            toHigh: 1.0
        ))

        var fillWidth: CGFloat
        var fillRect: NSRect
        var active: NSBezierPath

        if fillOrigin == 0 {
            guard doubleValue > minValue else { return }

            fillWidth = (rect.width - rect.height) * value + rect.height
            fillRect = NSRect(x: rect.origin.x, y: rect.origin.y + 0.5, width: fillWidth, height: rect.size.height - 1)
            active = NSBezierPath(roundedRect: fillRect, xRadius: cornerRadius, yRadius: cornerRadius)
            color.setFill()
            active.fill()
        } else {
            guard abs(value - fillOrigin) > 0.02 else { return }

            let left = value < fillOrigin
            fillWidth = (rect.width - rect.height) * abs(value - fillOrigin) + (rect.height / 2)
            let x = CGFloat(mapNumber(
                fillOrigin,
                fromLow: 0.0,
                fromHigh: 1.0,
                toLow: rect.minX,
                toHigh: rect.maxX
            ))
            fillRect = NSRect(
                x: left ? x - fillWidth : x,
                y: rect.origin.y + 0.5,
                width: fillWidth,
                height: rect.size.height - 1
            )
            active = NSBezierPath(
                roundedRectangle: fillRect,
                byRoundingCorners: left ? [.minXMinY, .minXMaxY] : [.maxXMinY, .maxXMaxY],
                withRadius: cornerRadius
            )
            color.setFill()
            active.fill()
        }
    }
}

// MARK: - ClickThroughImageView

class ClickThroughImageView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        subviews.first { subview in subview.hitTest(point) != nil }
    }
}

// MARK: - Slider

class Slider: NSSlider {
    // MARK: Lifecycle

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    // MARK: Internal

    @IBInspectable dynamic var scrollPrecision: CGFloat = 1

    var color: NSColor {
        get { (cell as! SliderCell).color }
        set { (cell as! SliderCell).color = newValue }
    }

    var sliderCell: SliderCell { cell as! SliderCell }

    override func mouseEntered(with _: NSEvent) {
        guard isEnabled, !isHidden else { return }
        transition(0.2)
        alphaValue = 1.0
    }

    override func mouseExited(with _: NSEvent) {
        AppleNativeControl.sliderTracking = false
        GammaControl.sliderTracking = false
        DDCControl.sliderTracking = false
        transition(0.8)
        alphaValue = 0.9
    }

    func setup() {
        refusesFirstResponder = true
        trackHover()
    }

    override func scrollWheel(with event: NSEvent) {
        guard isEnabled else { return }

        let range = Float(maxValue - minValue)
        var delta = Float(0)
        if isVertical, sliderType == .linear {
            delta = Float(event.scrollingDeltaY)
        } else if userInterfaceLayoutDirection == .rightToLeft {
            delta = Float(event.scrollingDeltaY + event.scrollingDeltaX)
        } else {
            delta = Float(event.scrollingDeltaY - event.scrollingDeltaX)
        }
        if event.isDirectionInvertedFromDevice {
            delta *= -1
        }

        switch event.phase {
        case .changed, .began, .mayBegin:
            if !AppleNativeControl.sliderTracking {
                AppleNativeControl.sliderTracking = true
                GammaControl.sliderTracking = true
                DDCControl.sliderTracking = true
            }
        case .ended, .cancelled, .stationary:
            if AppleNativeControl.sliderTracking {
                AppleNativeControl.sliderTracking = false
                GammaControl.sliderTracking = false
                DDCControl.sliderTracking = false
            }
        default:
            AppleNativeControl.sliderTracking = delta != 0
            GammaControl.sliderTracking = AppleNativeControl.sliderTracking
            DDCControl.sliderTracking = AppleNativeControl.sliderTracking
        }

        let increment = range * (delta / (150 * Float(scrollPrecision)))
        floatValue = floatValue + increment
        sendAction(action, to: target)
    }
}

// MARK: - VolumeSliderCell

class VolumeSliderCell: NSSliderCell {
    // MARK: Lifecycle

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    // MARK: Internal

    let volumeImage = NSImage(named: "volume-low")

    override func drawKnob(_ knobRect: NSRect) {
        super.drawKnob(knobRect)
        let imageRect = knobRect.smaller(by: 10)
        volumeImage?.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 0.7)
    }

    override func drawBar(inside aRect: NSRect, flipped _: Bool) {
        let rect = NSRect(x: aRect.origin.x, y: aRect.origin.y - 2.5, width: aRect.width, height: 10)
        let barRadius = CGFloat(4)
        let value = CGFloat((doubleValue - minValue) / (maxValue - minValue))
        let finalWidth = CGFloat(value * (controlView!.frame.size.width - 8))

        let bg = NSBezierPath(roundedRect: rect, xRadius: barRadius, yRadius: barRadius)
        let color = isEnabled ? peach : (peach.blended(withFraction: 0.5, of: gray) ?? gray)
        color.withAlphaComponent(0.3).setFill()
        bg.fill()

        let leftRect = NSRect(x: rect.origin.x, y: rect.origin.y, width: finalWidth, height: rect.size.height)
        let active = NSBezierPath(roundedRect: leftRect, xRadius: barRadius, yRadius: barRadius)
        color.withAlphaComponent(0.7).setFill()
        active.fill()
    }
}

// MARK: - VolumeSlider

class VolumeSlider: NSSlider {
    // MARK: Lifecycle

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    // MARK: Internal

    override var knobThickness: CGFloat { 6 }

    override func mouseEntered(with _: NSEvent) {
        guard isEnabled, !isHidden else { return }
        transition(0.2)
        alphaValue = 1.0
    }

    override func mouseExited(with _: NSEvent) {
        transition(0.5)
        alphaValue = 0.7
    }

    func setup() {
        trackHover()
    }
}
