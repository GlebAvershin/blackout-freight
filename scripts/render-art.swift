import AppKit

func rgb(_ hex: Int, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: a)
}

func shape(_ points: [(CGFloat, CGFloat)], _ color: NSColor) {
    let p = NSBezierPath()
    p.move(to: NSPoint(x: points[0].0, y: points[0].1))
    for (x, y) in points.dropFirst() { p.line(to: NSPoint(x: x, y: y)) }
    p.close()
    color.setFill()
    p.fill()
}

func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: NSColor, _ radius: CGFloat = 0) {
    color.setFill()
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: radius, yRadius: radius).fill()
}

func words(_ text: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, _ color: NSColor, _ weight: NSFont.Weight = .black) {
    (text as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .kern: size * 0.035
    ])
}

func cell(_ x: CGFloat, _ y: CGFloat, _ scale: CGFloat, _ purple: Bool = false) {
    NSGraphicsContext.saveGraphicsState()
    let transform = AffineTransform(translationByX: x, byY: y) as NSAffineTransform
    transform.scale(by: scale)
    transform.concat()
    let accent = purple ? 0xe083ff : 0x4ef4ed
    for i in (1...14).reversed() {
        let pad = CGFloat(i) * 3
        rect(-pad, -pad, 178 + 2 * pad, 123 + 2 * pad, rgb(accent, 0.015), 13 + pad)
    }
    shape([(0,123),(34,149),(213,149),(178,123)], rgb(0x567188))
    shape([(178,0),(213,25),(213,149),(178,123)], rgb(0x26344e))
    rect(0, 0, 178, 123, rgb(0x071222), 12)
    rect(5, 5, 168, 113, rgb(0x20374a), 9)
    rect(13, 15, 152, 93, rgb(0x0c182a), 5)
    for i in 0..<3 {
        let left = CGFloat(25 + 44 * i)
        rect(left, 26, 38, 71, rgb(accent), 5)
        rect(left + 4, 81, 30, 10, rgb(0xffffff, 0.4), 3)
    }
    shape([(64,149),(83,166),(142,166),(123,149)], rgb(0x9aadc3))
    NSGraphicsContext.restoreGraphicsState()
}

func depot(_ w: CGFloat, _ h: CGFloat, _ purple: Bool = false) {
    let bounds = NSRect(x: 0, y: 0, width: w, height: h)
    NSGradient(starting: rgb(0x152638), ending: rgb(0x050a14))!.draw(in: bounds, angle: 90)
    let vx = w * 0.58, vy = h * 0.49
    shape([(0,0),(w,0),(vx,vy)], rgb(0x111d2f))
    for i in 0...10 {
        let x = CGFloat(i) * w / 10
        shape([(x - 2,0),(x + 2,0),(vx,vy)], rgb(0x5b7893, 0.36))
    }
    for i in 1...6 {
        let p = CGFloat(i) / 7
        let y = vy * (1 - p * p)
        rect(0, y, w, 1 + p * 4, rgb(0x536c88, 0.22))
    }
    shape([(0,h),(0,h*0.29),(vx,vy),(w*0.18,h)], rgb(0x24334b))
    shape([(w,h),(w,h*0.27),(vx,vy),(w*0.91,h)], rgb(0x203047))
    for i in 0...4 {
        let x = CGFloat(i) * w * 0.055
        shape([(x,h),(x + w * 0.026,h),(vx,vy),(x,h*0.28)], rgb(0x0e182b, 0.72))
        let right = w - x
        shape([(right,h),(right - w*0.022,h),(vx,vy),(right,h*0.28)], rgb(0x0d1728, 0.75))
    }
    let amber = rgb(0xffb950)
    rect(vx - w*0.09, vy, w*0.18, h*0.23, rgb(0x071220), 4)
    rect(vx - w*0.087, vy, w*0.008, h*0.22, amber, 3)
    rect(vx + w*0.079, vy, w*0.008, h*0.22, amber, 3)
    rect(vx - w*0.087, vy + h*0.213, w*0.174, h*0.009, amber, 3)
    if purple { rect(0,0,w,h,rgb(0x19062f,0.58)) }
}

func drone(_ x: CGFloat, _ y: CGFloat, _ s: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    let transform = AffineTransform(translationByX: x, byY: y) as NSAffineTransform
    transform.scale(by: s)
    transform.concat()
    shape([(57,64),(180,64),(246,-77),(-12,-77)], rgb(0xff373b, 0.1))
    for i in (1...12).reversed() {
        let pad = CGFloat(i)*4
        rect(40-pad, 55-pad, 166+pad*2, 18+pad*2, rgb(0xff2c3a,0.023), pad)
    }
    shape([(0,59),(44,96),(200,96),(248,61),(201,18),(40,18)], rgb(0x151e34))
    shape([(44,96),(68,109),(183,109),(200,96)], rgb(0x8290a6))
    shape([(0,59),(40,18),(3,13),(-26,40)], rgb(0x33435e))
    shape([(248,61),(201,18),(248,13),(274,40)], rgb(0x33435e))
    rect(38, 51, 171, 22, rgb(0xff4c55), 8)
    rect(47, 60, 152, 6, rgb(0xffc2bd, 0.9), 3)
    rect(5, 19, 26, 7, rgb(0xff4c55), 2)
    rect(218, 19, 26, 7, rgb(0xff4c55), 2)
    NSGraphicsContext.restoreGraphicsState()
}

func png(_ name: String, _ width: Int, _ height: Int, _ draw: (CGFloat, CGFloat) -> Void) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    draw(CGFloat(width), CGFloat(height))
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "dist/" + name))
}

try png("game-icon.png", 512, 512) { w, h in
    depot(w,h)
    drone(129, 328, 1.01)
    cell(93, 100, 1.55)
    rect(105, 58, 305, 6, rgb(0xffb950), 3)
}
try png("aurora-pass.png", 512, 512) { w, h in
    depot(w,h,true)
    for i in 0..<4 {
        let pad = CGFloat(42 + 18 * i)
        let circle = NSBezierPath(ovalIn: NSRect(x: pad,y: pad,width: w-2*pad,height: h-2*pad))
        circle.lineWidth = i == 1 ? 4 : 1
        rgb(0xb382fc, i == 1 ? 0.65 : 0.3).setStroke()
        circle.stroke()
    }
    cell(96, 140, 1.48, true)
}
try png("depot-key-art.png", 1920, 1080) { w, h in
    depot(w,h)
    drone(1110, 610, 2.24)
    cell(1170, 190, 2.8)
    for i in 0..<11 {
        let x = CGFloat(i)*67 + 1090
        shape([(x,105),(x+32,105),(x+83,154),(x+51,154)], rgb(0xffb950,0.72))
    }
    shape([(0,0),(0,h),(1080,h),(885,0)], rgb(0x07101d,0.92))
    rect(115, 820, 78, 7, rgb(0xffb950), 3)
    words("DEPOT 07   /   NIGHT SHIFT", 115, 755, 29, rgb(0xffb950), .bold)
    words("BLACKOUT", 105, 562, 132, rgb(0xf1fbff))
    words("FREIGHT", 105, 419, 132, rgb(0xf1fbff))
    rect(115, 375, 710, 3, rgb(0x3b576f))
    words("TAKE THE CELL. RUN TO THE LIGHT.", 115, 310, 33, rgb(0x69ede9), .bold)
    words("SOLO  /  CO-OP", 115, 249, 23, rgb(0xb8cad9), .semibold)
}
