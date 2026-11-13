import AppKit
let folder = CommandLine.arguments[1]
let titles = ["CARRY THE SIGNAL", "IT HUNTS THE CARRIER", "BROADCAST OR SHELTER?"]
for (index, title) in titles.enumerated() {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil, pixelsWide:1280, pixelsHigh:100,
        bitsPerSample:8, samplesPerPixel:4, hasAlpha:true, isPlanar:false, colorSpaceName:.deviceRGB, bytesPerRow:0, bitsPerPixel:0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:bitmap)
    let attributes: [NSAttributedString.Key: Any] = [.font:NSFont.systemFont(ofSize:36,weight:.heavy), .foregroundColor:NSColor.white]
    let size = (title as NSString).size(withAttributes:attributes)
    NSColor(srgbRed:0.03,green:0.07,blue:0.13,alpha:0.88).setFill()
    NSBezierPath(roundedRect:NSRect(x:(1280-size.width)/2-20,y:18,width:size.width+40,height:64),xRadius:8,yRadius:8).fill()
    (title as NSString).draw(at:NSPoint(x:(1280-size.width)/2,y:31),withAttributes:attributes)
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"\(folder)/caption-\(index).png"))
}
