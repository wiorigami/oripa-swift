// Port of `oripa-port/src/js/ui/dialogs/color_picker.js` (Android `widget/ColorPicker`,
// `dialog/ColorPickerDialogFragment`, `util/ColorUtil` + the `android.graphics.Color`
// HSV subset used by the fold Overlap settings).
//
// Public pieces:
//   FoldColorMath          int <-> HSV helpers (Java math, 0xAARRGGBB colour ints)
//   FoldColorPickerRow     the ColorPicker widget row (ring swatch + title + #RRGGBB)
//   FoldColorPickerDialog  Material HSV dialog: default/current/new swatches, hue ring
//                          (hue increases counter-clockwise, 0 deg = east, like the Java
//                          touch math), saturation/value square, ring cursors and the
//                          "Set Color" hex input dialog.
import SwiftUI
import ORIPACore

// MARK: - Colour math (android.graphics.Color / util/ColorUtil)

/// Port of the shared colour utilities (`dialogs.colorUtils` in the JS port).
public enum FoldColorMath {

    /// `android.graphics.Color.colorToHSV` (Alpha ignored).
    public static func colorToHSV(_ color: UInt32) -> (h: Double, s: Double, v: Double) {
        let r = Double((color >> 16) & 0xFF)
        let g = Double((color >> 8) & 0xFF)
        let b = Double(color & 0xFF)
        let maxValue = max(r, max(g, b))
        let minValue = min(r, min(g, b))
        let delta = maxValue - minValue
        let v = maxValue / 255.0
        let s = maxValue == 0 ? 0 : delta / maxValue
        var h: Double
        if delta == 0 {
            h = 0
        } else {
            if r == maxValue {
                h = (g - b) / delta
            } else if g == maxValue {
                h = 2.0 + (b - r) / delta
            } else {
                h = 4.0 + (r - g) / delta
            }
            h *= 60.0
            if h < 0 { h += 360.0 }
        }
        return (h, s, v)
    }

    /// `android.graphics.Color.HSVToColor` (opaque).
    public static func hsvToColor(_ h: Double, _ s: Double, _ v: Double) -> UInt32 {
        var hue = h
        if hue < 0 { hue = 0 } else if hue > 360 { hue = 360 }
        let hh = hue / 60.0
        let i = Int(hh.rounded(.down))
        let f = hh - Double(i)
        let p = v * (1.0 - s)
        let q = v * (1.0 - s * f)
        let t = v * (1.0 - s * (1.0 - f))
        var r = 0.0, g = 0.0, b = 0.0
        switch i {
        case 0: r = v; g = t; b = p
        case 1: r = q; g = v; b = p
        case 2: r = p; g = v; b = t
        case 3: r = p; g = q; b = v
        case 4: r = t; g = p; b = v
        case 5: r = v; g = p; b = q
        default: r = 0; g = 0; b = 0
        }
        func byte(_ x: Double) -> UInt32 {
            let rounded = (x * 255.0).rounded()
            return UInt32(min(255, max(0, rounded)))
        }
        return 0xFF00_0000 | (byte(r) << 16) | (byte(g) << 8) | byte(b)
    }

    /// `intToStringRgb`: "#RRGGBB" (uppercase, alpha dropped).
    public static func intToStringRgb(_ color: UInt32) -> String {
        let rgb = color & 0x00FF_FFFF
        var hex = String(rgb, radix: 16, uppercase: true)
        while hex.count < 6 { hex = "0" + hex }
        return "#" + hex
    }

    /// `intToStringRgbNoHash`: "RRGGBB" (used by the hex text field).
    public static func intToStringRgbNoHash(_ color: UInt32) -> String {
        String(intToStringRgb(color).dropFirst())
    }

    /// `ColorUtil.getHueAngleDeg`.
    public static func getHueAngleDeg(_ color: UInt32) -> Double {
        colorToHSV(color).h
    }

    /// `ColorUtil.getSaturatedHue`: the fully saturated hue colour of the ring segment.
    public static func getSaturatedHue(_ hueDeg: Double) -> UInt32 {
        hsvToColor(hueDeg, 1.0, 1.0)
    }

    /// `ColorUtil.getRainbow()`: red, magenta, blue, cyan, green, yellow, red.
    public static func getRainbow() -> [UInt32] {
        [0xFFFF_0000, 0xFFFF_00FF, 0xFF00_00FF, 0xFF00_FFFF, 0xFF00_FF00, 0xFFFF_FF00, 0xFFFF_0000]
    }

    /// Java `Color.parseColor` subset used by the hex dialog: "#RRGGBB" only, else `nil`.
    public static func parseColor(_ text: String) -> UInt32? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("#") else { return nil }
        let digits = trimmed.dropFirst()
        guard digits.count == 6, digits.allSatisfy({ $0.isHexDigit }) else { return nil }
        guard let value = UInt32(digits, radix: 16) else { return nil }
        return 0xFF00_0000 | value
    }

    /// `ColorUtils.calculateContrast` (WCAG relative-luminance ratio).
    public static func calculateContrast(_ color1: UInt32, _ color2: UInt32) -> Double {
        func channel(_ x: Double) -> Double {
            let c = x / 255.0
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        func luminance(_ color: UInt32) -> Double {
            let r = channel(Double((color >> 16) & 0xFF))
            let g = channel(Double((color >> 8) & 0xFF))
            let b = channel(Double(color & 0xFF))
            return 0.2126 * r + 0.7152 * g + 0.0722 * b
        }
        var l1 = luminance(color1)
        var l2 = luminance(color2)
        if l1 < l2 { swap(&l1, &l2) }
        return (l1 + 0.05) / (l2 + 0.05)
    }

    /// 0xAARRGGBB -> SwiftUI Color.
    public static func color(_ argb: UInt32) -> SwiftUI.Color {
        let a = Double((argb >> 24) & 0xFF) / 255.0
        let r = Double((argb >> 16) & 0xFF) / 255.0
        let g = Double((argb >> 8) & 0xFF) / 255.0
        let b = Double(argb & 0xFF) / 255.0
        return SwiftUI.Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - ColorPicker row widget (res/layout/view_color_picker.xml)

/// `dialogs.colorPicker`: ring swatch + title + `#RRGGBB` summary; taps open the dialog.
struct FoldColorPickerRow: View {
    let title: String
    let currentColor: UInt32
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(FoldColorMath.color(currentColor))
                    Circle()
                        .strokeBorder(SwiftUI.Color(white: 0, opacity: 0.54), lineWidth: 2)
                    Circle()
                        .strokeBorder(SwiftUI.Color.white, lineWidth: 2)
                        .padding(2)
                }
                .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16))
                        .foregroundStyle(FoldTheme.textPrimary)
                    Text(FoldColorMath.intToStringRgb(currentColor))
                        .font(.system(size: 14))
                        .foregroundStyle(FoldTheme.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 18)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(FoldPressableStyle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - HSV color picker dialog (dialog/ColorPickerDialogFragment)

/// Material HSV picker: default / current / new swatches, hue ring + SV square with the
/// Java touch math, hex input via the "Set Color" dialog. OK reports the picked colour;
/// Cancel discards (like the Android dialog).
struct FoldColorPickerDialog: View {
    let defaultColor: UInt32
    let currentColor: UInt32
    let onCancel: () -> Void
    let onOK: (UInt32) -> Void

    @State private var newColor: UInt32
    @State private var newHue: Double
    @State private var showsHexDialog = false

    init(defaultColor: UInt32,
         currentColor: UInt32,
         onCancel: @escaping () -> Void,
         onOK: @escaping (UInt32) -> Void) {
        self.defaultColor = defaultColor
        self.currentColor = currentColor
        self.onCancel = onCancel
        self.onOK = onOK
        _newColor = State(initialValue: currentColor)
        _newHue = State(initialValue: FoldColorMath.getHueAngleDeg(currentColor))
    }

    var body: some View {
        FoldDialogScrim(dismissOnScrimTap: false) {
            FoldDialogCard(title: nil,
                           icon: nil,
                           contentPadding: EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0),
                           buttons: [
                               FoldDialogButton(text: "cancel", action: onCancel),
                               FoldDialogButton(text: "ok", primary: true, action: { onOK(newColor) }),
                           ]) {
                VStack(alignment: .leading, spacing: 0) {
                    swatches
                    FoldColorWheel(hueDeg: newHue,
                                   color: newColor,
                                   onChange: { color, hue in
                                       newColor = color
                                       newHue = hue
                                   })
                        .frame(maxWidth: 320)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                }
            }
            .frame(maxWidth: 360)
            .overlay {
                if showsHexDialog {
                    FoldColorHexDialog(
                        initialHex: FoldColorMath.intToStringRgbNoHash(newColor),
                        onCancel: { showsHexDialog = false },
                        onApply: { parsed in
                            showsHexDialog = false
                            guard let parsed else { return }
                            newColor = parsed
                            newHue = FoldColorMath.getHueAngleDeg(parsed)
                        })
                }
            }
        }
    }

    // Default / current / new swatch buttons (88dp tall, equal thirds).
    private var swatches: some View {
        HStack(spacing: 0) {
            swatchButton(color: defaultColor) {
                newColor = defaultColor
                newHue = FoldColorMath.getHueAngleDeg(defaultColor)
            }
            swatchButton(color: currentColor) {
                newColor = currentColor
                newHue = FoldColorMath.getHueAngleDeg(currentColor)
            }
            swatchButton(color: newColor) {
                showsHexDialog = true
            }
        }
        .frame(height: 88)
    }

    private func swatchButton(color: UInt32, action: @escaping () -> Void) -> some View {
        let textColor: SwiftUI.Color = FoldColorMath.calculateContrast(0xDE00_0000, color) < 7.0
            ? .white
            : SwiftUI.Color(white: 0, opacity: 0.87)
        return Button(action: action) {
            Text(FoldColorMath.intToStringRgb(color))
                .font(.system(size: 14, weight: .medium))
                .kerning(0.28)
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(FoldColorMath.color(color))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hue ring + saturation/value square (widget/ColorPicker geometry)

/// The HSV wheel: hue ring (hue increases counter-clockwise from east) and the inscribed
/// saturation/value square, with two cursors. All coordinates/maths mirror the Java
/// `ColorPicker` touch handlers.
private struct FoldColorWheel: View {
    let hueDeg: Double
    let color: UInt32
    let onChange: (UInt32, Double) -> Void

    /// Which part of the wheel the current drag started on (ring / SV square).
    private enum DragTarget { case hue, satVal }
    @State private var dragTarget: DragTarget?
    /// Saturation/value captured when the hue drag starts (Java hue ring behaviour).
    @State private var dragStartSaturation: Double = 1
    @State private var dragStartValue: Double = 1

    private static let ringThickness: CGFloat = 20
    private static let cursorSize: CGFloat = 20
    /// `dimen/color_picker_half_thickness`: SV square inset from the Java touch mapping.
    private static let satValPadding: CGFloat = 10

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let ring = Self.ringThickness
            let hueRadius = size / 2 - 1 - ring / 2
            let svSide = (((size / 2) - ring - 10) * 1.414_213_562).rounded()
            let svLeft = (geometry.size.width - svSide) / 2
            let svTop = (geometry.size.height - svSide) / 2
            let hsv = FoldColorMath.colorToHSV(color)

            ZStack(alignment: .topLeading) {
                Circle()
                    .strokeBorder(hueRingGradient, lineWidth: ring)
                    .frame(width: size, height: size)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                satValSquare
                    .frame(width: svSide, height: svSide)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                // Saturation/value cursor (tinted with the picked colour).
                Circle()
                    .fill(FoldColorMath.color(color))
                    .frame(width: Self.cursorSize, height: Self.cursorSize)
                    .overlay(Circle().strokeBorder(SwiftUI.Color(white: 0, opacity: 0.54), lineWidth: 2))
                    .overlay(Circle().strokeBorder(SwiftUI.Color.white, lineWidth: 2).padding(2))
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                    .position(x: svLeft + Self.satValPadding
                                   + CGFloat(hsv.s) * (svSide - Self.satValPadding * 2),
                              y: svTop + Self.satValPadding
                                   + CGFloat(1.0 - hsv.v) * (svSide - Self.satValPadding * 2))

                // Hue cursor (tinted with the saturated hue).
                Circle()
                    .fill(FoldColorMath.color(FoldColorMath.getSaturatedHue(hueDeg)))
                    .frame(width: Self.cursorSize, height: Self.cursorSize)
                    .overlay(Circle().strokeBorder(SwiftUI.Color(white: 0, opacity: 0.54), lineWidth: 2))
                    .overlay(Circle().strokeBorder(SwiftUI.Color.white, lineWidth: 2).padding(2))
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                    .position(x: geometry.size.width / 2
                                   + hueRadius * CGFloat(cos(hueDeg * .pi / 180.0)),
                              y: geometry.size.height / 2
                                   - hueRadius * CGFloat(sin(hueDeg * .pi / 180.0)))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        handleDrag(location: gesture.location,
                                   size: size,
                                   svLeft: svLeft,
                                   svTop: svTop,
                                   svSide: svSide)
                    }
                    .onEnded { _ in dragTarget = nil }
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// Hue ring gradient: AngularGradient sweeps clockwise on screen, while the Java hue
    /// increases counter-clockwise, so the stops run hue = 360 - angle.
    private var hueRingGradient: AngularGradient {
        var stops: [Gradient.Stop] = []
        let step = 5.0
        let count = Int(360.0 / step)
        for i in 0...count {
            let clockwiseDeg = Double(i) * step
            var hue = 360.0 - clockwiseDeg
            if hue >= 360.0 { hue -= 360.0 }
            stops.append(Gradient.Stop(color: FoldColorMath.color(FoldColorMath.getSaturatedHue(hue)),
                                       location: Double(i) / Double(count)))
        }
        return AngularGradient(gradient: Gradient(stops: stops),
                               center: .center,
                               startAngle: .degrees(0),
                               endAngle: .degrees(360))
    }

    /// solid hue + white -> transparent (left to right) + transparent -> black (top to bottom).
    private var satValSquare: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(rect), with: .color(FoldColorMath.color(FoldColorMath.getSaturatedHue(hueDeg))))
            context.fill(Path(rect),
                         with: .linearGradient(Gradient(colors: [SwiftUI.Color.white, .clear]),
                                               startPoint: CGPoint(x: 0, y: 0),
                                               endPoint: CGPoint(x: size.width, y: 0)))
            context.fill(Path(rect),
                         with: .linearGradient(Gradient(colors: [.clear, SwiftUI.Color.black]),
                                               startPoint: CGPoint(x: 0, y: 0),
                                               endPoint: CGPoint(x: 0, y: size.height)))
        }
    }

    private func handleDrag(location: CGPoint,
                            size: CGFloat,
                            svLeft: CGFloat,
                            svTop: CGFloat,
                            svSide: CGFloat) {
        let svRect = CGRect(x: svLeft, y: svTop, width: svSide, height: svSide)
        if dragTarget == nil {
            if svRect.contains(location) {
                dragTarget = .satVal
            } else {
                dragTarget = .hue
                let hsv = FoldColorMath.colorToHSV(color)
                dragStartSaturation = hsv.s
                dragStartValue = hsv.v
            }
        }
        switch dragTarget {
        case .hue:
            let hue = hueAngle(location: location, size: size)
            let newColor = FoldColorMath.hsvToColor(hue, dragStartSaturation, dragStartValue)
            onChange(newColor, hue)
        case .satVal:
            let side = svSide - Self.satValPadding * 2
            guard side > 0 else { return }
            let s = min(1, max(0, (location.x - svLeft - Self.satValPadding) / side))
            let v = min(1, max(0, (location.y - svTop - Self.satValPadding) / side))
            let newColor = FoldColorMath.hsvToColor(hueDeg, Double(s), Double(1.0 - v))
            onChange(newColor, hueDeg)
        case .none:
            break
        }
    }

    /// Java `hueFromEvent`: `atan2(size/2 - y, x - size/2)`, negative angles += 360.
    private func hueAngle(location: CGPoint, size: CGFloat) -> Double {
        var deg = atan2(Double(size / 2 - location.y), Double(location.x - size / 2)) * 180.0 / .pi
        if deg < 0 { deg += 360.0 }
        return deg
    }
}

// MARK: - Hex "Set Color" dialog (dialog_edittext_color.xml)

/// Android `EditText` dialog: prefix "#", hint "hex color, e.g. #abc012", 3/6-digit
/// expansion exactly like `lambda$showDialogEditColor$5`; invalid input is discarded.
struct FoldColorHexDialog: View {
    let initialHex: String
    let onCancel: () -> Void
    /// `nil` = invalid input (the Java catches the IllegalArgumentException and dismisses).
    let onApply: (UInt32?) -> Void

    @State private var text: String
    @FocusState private var focused: Bool

    init(initialHex: String,
         onCancel: @escaping () -> Void,
         onApply: @escaping (UInt32?) -> Void) {
        self.initialHex = initialHex
        self.onCancel = onCancel
        self.onApply = onApply
        _text = State(initialValue: initialHex)
    }

    var body: some View {
        FoldDialogScrim(dismissOnScrimTap: false) {
            FoldDialogCard(title: "Set Color",
                           icon: nil,
                           contentPadding: EdgeInsets(top: 16, leading: 24, bottom: 8, trailing: 24),
                           buttons: [
                               FoldDialogButton(text: "cancel", action: onCancel),
                               FoldDialogButton(text: "ok", primary: true, action: apply),
                           ]) {
                HStack(spacing: 4) {
                    Text("#")
                        .font(.system(size: 16))
                        .foregroundStyle(FoldTheme.textSecondary)
                    TextField("hex color, e.g. #abc012", text: $text)
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundStyle(FoldTheme.textPrimary)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .focused($focused)
                }
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(FoldTheme.divider)
                        .frame(height: 2)
                }
            }
        }
        .onAppear { focused = true }
    }

    private func apply() {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.count >= 6 {
            value = "#" + String(value.prefix(6))
        } else if value.count >= 3 {
            let chars = Array(value.prefix(3))
            value = "#" + chars.map { String($0) + String($0) }.joined()
        } else {
            onApply(nil)
            return
        }
        guard let parsed = FoldColorMath.parseColor(value) else {
            onApply(nil)
            return
        }
        onApply(parsed)
    }
}
