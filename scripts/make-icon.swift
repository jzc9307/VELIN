import AppKit
let dest = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let bg = NSBezierPath(roundedRect: NSRect(x: 42, y: 42, width: 940, height: 940), xRadius: 210, yRadius: 210)
NSGradient(starting: NSColor(red:0.12,green:0.18,blue:0.20,alpha:1), ending: NSColor(red:0.06,green:0.08,blue:0.12,alpha:1))!.draw(in: bg, angle: -50)
NSColor(white:1,alpha:0.09).setStroke();bg.lineWidth=3;bg.stroke()
let left = NSBezierPath();left.move(to:NSPoint(x:270,y:700));left.curve(to:NSPoint(x:500,y:265),controlPoint1:NSPoint(x:290,y:490),controlPoint2:NSPoint(x:400,y:330));left.lineWidth=92;left.lineCapStyle = .round
NSColor(red:0.635,green:0.925,blue:0.835,alpha:1).setStroke();left.stroke()
let right = NSBezierPath();right.move(to:NSPoint(x:500,y:265));right.curve(to:NSPoint(x:760,y:740),controlPoint1:NSPoint(x:555,y:495),controlPoint2:NSPoint(x:680,y:670));right.lineWidth=92;right.lineCapStyle = .round
NSColor(red:0.72,green:0.643,blue:1,alpha:1).setStroke();right.stroke()
NSColor(red:0.635,green:0.925,blue:0.835,alpha:1).setFill();NSBezierPath(ovalIn:NSRect(x:478,y:700,width:58,height:58)).fill()
image.unlockFocus()
let rep = NSBitmapImageRep(data:image.tiffRepresentation!)!
try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:dest))
