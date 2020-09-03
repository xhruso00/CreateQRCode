import Cocoa
import Automator

class CreateQRCodeOperation: Operation {

    private weak var action : CreateQRCode?
    private var qrImage : AutomatorQRImage
    private var sourcePath : String?
    private var saveFolder : String?
    private var fileType: String
    private var index : Int
    
    init(action : CreateQRCode,
         qrImage : AutomatorQRImage,
         sourcePath : String?,
         saveFolder : String?,
         fileType : String,
         index : Int = 0) {
        
        self.action = action
        self.qrImage = qrImage
        self.sourcePath = sourcePath
        self.saveFolder = saveFolder
        self.fileType = fileType
        self.index = index
        super.init()
    }
    
    func saveURL() -> URL {
        let desktopPath = (NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true) as [String]).first ?? ("~/Desktop/" as NSString).expandingTildeInPath
        var newURL : URL
        var fileName = String(format: "qr_%04lu", index)
        if sourcePath != nil {
            if FileManager.default.fileExists(atPath: sourcePath!) == true {
                fileName = ((sourcePath! as NSString).lastPathComponent as NSString).deletingPathExtension
            }
        }
        
        if saveFolder != nil {
            newURL = URL(fileURLWithPath: (saveFolder! as NSString).expandingTildeInPath)
        } else {
            newURL = URL(fileURLWithPath: desktopPath)
        }
        newURL.appendPathComponent(fileName)
        newURL.appendPathExtension(fileType.lowercased())
        return newURL
    }
    
    override func main() {
        if isCancelled == true {
            return
        }
        do {
            let fileURL = saveURL()
            try qrImage.save(to: fileURL, fileType: fileType)
            action?.appendOutput(url: fileURL)
        } catch let error {
            action?.cancelDueToError(error: error)
        }
    }
}
