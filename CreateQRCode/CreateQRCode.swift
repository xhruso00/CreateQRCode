import Cocoa
import Automator

public let chosenColor = "chosenColor"
public  let chosenSize = "chosenSize"
public  let chosenErrorCorrection = "chosenErrorCorrection"
public  let transparentBackground = "transparentBackground"
public  let targetFolderPath = "targetFolderPath"
public  let chosenFiletype = "chosenFiletype"

class CreateQRCode: AMBundleAction {
    
    @IBOutlet weak var previewImageWell: NSImageView!
    @IBOutlet weak var fileTypePopupButton: NSPopUpButton!
    @IBOutlet weak var pixelColorWell: NSColorWell!
    
    var queue : OperationQueue = OperationQueue()
    var isFinished : Bool = false
    var numberOfOperations : Int = 0
    var outputURLs : [URL] = []
    
    
    
    override func opened() {
        if #available(OSX 10.13.4, *) { } else { removeHEIFFromMenu() }
        pixelColorWell.color = colorFromParameters()
        updatePreview()
    }
    
    func removeHEIFFromMenu() {
        let index = fileTypePopupButton.indexOfItem(withTitle: "HEIF")
        if index != -1 { fileTypePopupButton.menu!.removeItem(at: index) }
    }
    
    func colorFromParameters() -> NSColor {
        let colorAsNumbers = parameters?[chosenColor] as? [NSNumber]
        let red = CGFloat(colorAsNumbers?[0].floatValue ?? 0)
        let green = CGFloat(colorAsNumbers?[1].floatValue ?? 0)
        let blue = CGFloat(colorAsNumbers?[2].floatValue ?? 0)
        let alpha = CGFloat(colorAsNumbers?[3].floatValue ?? 1)
        return NSColor(deviceRed: red, green: green, blue: blue, alpha: alpha)
    }
    
    override func updateParameters()
    {
        let color = pixelColorWell.color
        let colorAsNumbers = [color.redComponent as NSNumber, color.greenComponent as NSNumber, color.blueComponent as NSNumber, color.alphaComponent as NSNumber]
        if parameters != nil {
            parameters![chosenColor] = colorAsNumbers
        }
        updatePreview()
    }
    
    func updatePreview() {
        let correctionLevel = parameters?[chosenErrorCorrection] as? String ?? "L"
        let isTransparent = parameters?[transparentBackground] as? Bool ?? false
        let chosenWidth = parameters?[chosenSize] as? Int ?? 300
        let automatorImage = AutomatorQRImage(textOrPath: "Think Different",
                                              correctionLevel: correctionLevel,
                                              isTransparent: isTransparent,
                                              outputWidth: chosenWidth)
        automatorImage.changeForegroundColor(with: colorFromParameters())
        previewImageWell.image = automatorImage.nsImage()
    }
    
    @IBAction func uiElementHasChanged(_ sender: Any) {
        updateParameters()
        updatePreview()
    }
    
    func QRImage(textOrPath : String) -> AutomatorQRImage {
        let correctionLevel = parameters?[chosenErrorCorrection] as? String ?? "L"
        let isTransparent = parameters?[transparentBackground] as? Bool ?? false
        let width = parameters?[chosenSize] as? Int ?? 300
        let image =  AutomatorQRImage(textOrPath: textOrPath,
                                      correctionLevel: correctionLevel,
                                      isTransparent: isTransparent,
                                      outputWidth: width)
        image.changeForegroundColor(with: colorFromParameters())
        return image
    }
    
    override func runAsynchronously(withInput input: Any?) {
        queue = OperationQueue()
        numberOfOperations = 0
        outputURLs = []
        isFinished = false
        
        //DUE TO GPU CICONTEXT CRASHING ON MORE THAN ONE THREAD
        queue.maxConcurrentOperationCount = 1
        progressValue = 0
        
        guard input != nil,
            let params = parameters,
            let input = input as? [String]
            else { return finishRunningWithError(nil) }
        
        let fileType = params[chosenFiletype] as? String ?? "PNG"
        numberOfOperations = input.count
        
        var index = 0
        
        for item in input {
            
            let operation = CreateQRCodeOperation(action: self,
                                                  qrImage: QRImage(textOrPath: item),
                                                  sourcePath: item,
                                                  saveFolder: parameters?[targetFolderPath] as? String,
                                                  fileType: fileType,
                                                  index: index)
            queue.addOperation(operation)
            index += 1
            
        }
        queue.waitUntilAllOperationsAreFinished()
        output = outputURLs
        finishRunningWithError(nil)
    }
    
    let lock = NSObject()
    public func appendOutput(url : URL) {
        objc_sync_enter(lock)
        progressValue += 1 / CGFloat(numberOfOperations)
        outputURLs.append(url)
        objc_sync_exit(lock)
    }
    
    func cancelDueToError(error : Error?) {
        objc_sync_enter(lock)
        if isFinished == false {
            isFinished = true
            cleanUp()
            finishRunningWithError(error)
        }
        objc_sync_exit(lock)
    }
    
    override func stop() {
        isFinished = true
        output = nil
        cleanUp()
        super.stop()
    }
    
    func cleanUp() {
        if queue.operationCount > 0 {
            queue.cancelAllOperations()
        }
    }
}
