import CoreImage
import Cocoa

extension CIImage {
    func convertToBezier() -> NSBezierPath {
        let shape = NSBezierPath()
        let bitmapRep = NSBitmapImageRep(ciImage: self)
        
        for y in 0 ..< bitmapRep.pixelsHigh {
            for x in 0 ..< bitmapRep.pixelsWide {
                var pixel : [Int] = [0, 0, 0, 0]
                bitmapRep.getPixel(&pixel, atX: x, y: y)
                if (pixel[0] == 0) {
                    shape.appendRect(CGRect(x: CGFloat(x),
                                            y: CGFloat(y),
                                            width: 1,
                                            height: 1))
                }
            }
        }
        return shape
    }
}

extension NSColor {
    func toHexString () -> String {
        // Convert colour to RGBA
        
        guard let color = usingColorSpace(.sRGB) else { return "#FFFFFF" }
        
        var r : CGFloat = 0
        var g : CGFloat = 0
        var b : CGFloat = 0
        var a : CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        let rgb:Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        return String(format: "#%06x", rgb)
    }
}

extension NSBezierPath {
    func svgPath() -> String {
        var path = ""
        
        for i in 0 ..< elementCount {
            var points = [CGPoint](repeating: .zero, count: 3)
            let type = self.element(at: i, associatedPoints: &points)
            
            switch type {
            case .moveTo:
                path += "M \(points[0].x) \(points[0].y) "
            case .lineTo:
                path += "L \(points[0].x) \(points[0].y) "
                
            case .curveTo:
                path += "C \(points[0].x) \(points[0].y), \(points[1].x) \(points[1].y), \(points[2].x) \(points[2].y)"
                
            case .closePath:
                path += "Z "
                
            @unknown default:
                break
            }
        }
        return path
    }
}
