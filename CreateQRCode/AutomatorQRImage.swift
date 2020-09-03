import Cocoa
import CoreImage

class AutomatorQRImage: NSObject {
    
    private var foregroundColor : CIColor = CIColor.black
    private var backgroundColor : CIColor {
        get {
            if isTransparent { return CIColor.clear }
            else { return CIColor.white }
        }
    }
    
    private var correctionLevel : String = "L"
    private var outputWidth : Int = 300
    private var isTransparent : Bool = false
    private var textOrPath : String?
    private var text : String?
    
    init(textOrPath : String,
         correctionLevel : String = "L",
         isTransparent : Bool = false,
         outputWidth : Int = 300) {
        
        self.correctionLevel = correctionLevel
        self.isTransparent = isTransparent
        self.outputWidth = outputWidth
        self.textOrPath = textOrPath
        super.init()
    }
    
    func nsImage() -> NSImage? {
        var image : NSImage?
        if let newImage = ciImage() {
            image = NSImage(size: newImage.extent.size)
            image!.addRepresentation(NSCIImageRep(ciImage: newImage))
        }
        return image
    }
    
    func cgImage() -> CGImage? {
        guard let image = ciImage() else { return nil }
        let context = CIContext()
        return context.createCGImage(image, from: image.extent)
    }
    
    func convertToTextIfNecessary() {
        if textOrPath != nil {
            if FileManager.default.fileExists(atPath: textOrPath!) {
                text = try? String(contentsOfFile: textOrPath!)
            } else {
                text = textOrPath!
            }
        }
    }
    
    func unscaledQrImage() -> CIImage? {
        convertToTextIfNecessary()
        guard
            let qrCodeFilter = CIFilter(name: "CIQRCodeGenerator"),
            let message = text?.data(using: .utf8) else { return nil }
        //var bytes: Data = data!
        qrCodeFilter.setDefaults()
        qrCodeFilter.setValue(message, forKey: "inputMessage")
        qrCodeFilter.setValue(correctionLevel, forKey: "inputCorrectionLevel")
        //var bytes: Data = data!
        return qrCodeFilter.outputImage
    }
    
    func ciImage() -> CIImage? {
        guard
            let qrImage = unscaledQrImage(),
            let falseColorFilter = CIFilter(name: "CIFalseColor") else { return nil }
        falseColorFilter.setDefaults()
        falseColorFilter.setValue(foregroundColor, forKey: "inputColor0")
        falseColorFilter.setValue(backgroundColor, forKey: "inputColor1")
        falseColorFilter.setValue(qrImage, forKey: kCIInputImageKey)
        if let colorizedImage = falseColorFilter.outputImage {
            return colorizedImage.transformed(by: transform(for: colorizedImage.extent))
        }
        return falseColorFilter.outputImage
    }
    
    func transform(for rect : CGRect) -> CGAffineTransform {
        return CGAffineTransform(scaleX: CGFloat(outputWidth) / rect.width,
                                 y: CGFloat(outputWidth) / rect.height)
    }
    
    public func changeForegroundColor(with color : NSColor) {
        if let foregroundColor = CIColor(color: color) {
            self.foregroundColor = foregroundColor
        }
    }
    
    public func save(to url: URL, fileType type : String = "PNG") throws {
        do {
            switch type {
            case "HEIF", "TIFF", "JPEG", "PNG":
                try saveBitmap(to: url, type: type)
                
            case "PDF", "EPS", "SVG":
                try saveVector(to: url, type: type)
            default:
                try saveBitmap(to: url, type: type)
            }
        } catch let error {
            throw error
        }
    }
    
    func saveVector(to fileURL : URL, type : String) throws {
        var data : Data?
        do {
            if (type == "SVG") {
                data = dataWithSVG()
            } else {
                data = dataWithPDF()
            }
            try data?.write(to: fileURL)
        } catch let error {
            throw error
        }
    }
    
    func saveBitmap(to fileURL : URL, type : String) throws {
        guard
            let image = ciImage(),
            let cs = CGColorSpace(name: CGColorSpace.displayP3) else { return }
        
        let options : [CIImageRepresentationOption : Any] =  [
            kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption : NSNumber(value: 1.0),
        ]
        let f = CIFormat.RGBAh
        let contextForSaving = CIContext()//options: [.useSoftwareRenderer : true])
        do {
            switch type {
            case "HEIF":
                if #available(OSX 10.13.4, *) {
                    
                    try contextForSaving.writeHEIFRepresentation(of: image, to: fileURL, format: f, colorSpace: cs, options: options)
                } else {
                    break
                }
            case "TIFF":
                try contextForSaving.writeTIFFRepresentation(of: image, to: fileURL, format: .RGBAh, colorSpace: cs, options: [:])
            case "JPEG":
                try contextForSaving.writeJPEGRepresentation(of: image, to: fileURL, colorSpace: cs, options: options)
            case "PNG":
                try contextForSaving.writePNGRepresentation(of: image, to: fileURL, format: .RGBAh, colorSpace: cs, options: [:])
            default:
                try contextForSaving.writePNGRepresentation(of: image, to: fileURL, format: .RGBAh, colorSpace: cs, options: [:])
            }
        } catch let error {
            throw error
        }
    }
    
    func dataWithSVG() -> Data? {
        guard let shape = unscaledQrImage()?.convertToBezier() else { return nil }
        var data = Data()
        let totalShapeWidth = shape.bounds.width + 2 * shape.bounds.origin.x
        let totalShapeHeight = shape.bounds.height + 2 * shape.bounds.origin.y
        let backgroundFill =  isTransparent ? "none" : NSColor(ciColor: backgroundColor).toHexString()
        var svg = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
            <svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="\(outputWidth)" height="\(outputWidth)"  xml:space="preserve">
            <!-- Generated by iQR - http://iqr.hrubasko.com -->
            <rect fill="\(backgroundFill)" x="0" y="0" width="\(outputWidth)" height="\(outputWidth)" />
            """ + "\r\n"
        let translateX = shape.bounds.origin.x
        let translateY = shape.bounds.origin.y
        let scaleX = CGFloat(outputWidth) / totalShapeWidth
        let scaleY = CGFloat(outputWidth) / totalShapeHeight
        let fill = NSColor(ciColor: foregroundColor).toHexString()
        svg = svg + """
            <g transform="translate(\(translateX), \(translateY)) scale(\(scaleX),\(scaleY))" fill="\(fill)" stroke="none">"
            """ + "\r\n"
        let svgPath = shape.svgPath()
        svg = svg + "\t<path d=\"\(svgPath)\"/>\r\n"
        svg = svg + "\t</g>\r\n"
        svg = svg + "</svg>"
        if let svgData = svg.data(using: .utf8) {
            data.append(svgData)
        }
        return data
    }
    
    func dataWithPDF() -> Data? {
        guard let shape = unscaledQrImage()?.convertToBezier() else { return nil }
        let pdfData = CFDataCreateMutable(kCFAllocatorDefault, 0)
        if pdfData != nil, let dataConsumer = CGDataConsumer(data: pdfData!) {
            var mediaBox = CGRect(x: 0, y: 0, width: outputWidth, height: outputWidth)
            if let context = CGContext(consumer: dataConsumer, mediaBox: &mediaBox, nil) {
                context.beginPDFPage(nil)
                if isTransparent == false {
                    context.setFillColor(CGColor.white)
                }
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext.init(cgContext: context, flipped: false)
                let totalShapeWidth = shape.bounds.width + 2 * shape.bounds.origin.x
                let totalShapeHeight = shape.bounds.height + 2 * shape.bounds.origin.y
                let transform = NSAffineTransform()
                transform.translateX(by: 0, yBy: CGFloat(outputWidth))
                transform.scaleX(by: 1, yBy: -1)
                transform.translateX(by: shape.bounds.origin.x, yBy: shape.bounds.origin.y)
                transform.scaleX(by: CGFloat(outputWidth) / totalShapeWidth, yBy: CGFloat(outputWidth) / totalShapeHeight)
                transform.concat()
                NSColor(ciColor: foregroundColor).setFill()
                shape.fill()
                NSGraphicsContext.restoreGraphicsState()
                context.endPDFPage()
                context.closePDF()
            }
        }
        return pdfData as Data?
    }
}
