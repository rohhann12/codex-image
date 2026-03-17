import AppKit
import Foundation

@MainActor
final class ClipboardImageSaver {
    static let shared = ClipboardImageSaver()

    enum SaveError: LocalizedError {
        case missingImage
        case invalidImage

        var errorDescription: String? {
            switch self {
            case .missingImage:
                return "Clipboard has no image"
            case .invalidImage:
                return "Clipboard image could not be saved"
            }
        }
    }

    var clipboardHasImage: Bool {
        let hasImage = NSImage(pasteboard: .general) != nil
        Logger.shared.log("Clipboard image check: \(hasImage)")
        return hasImage
    }

    func saveClipboardImage(into directory: URL) throws -> URL {
        Logger.shared.log("Saving clipboard image into directory \(directory.path)")
        guard let image = NSImage(pasteboard: .general) else {
            Logger.shared.log("Clipboard image missing at save time")
            throw SaveError.missingImage
        }

        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let png = bitmap.representation(using: .png, properties: [:])
        else {
            Logger.shared.log("Clipboard image could not be converted to PNG")
            throw SaveError.invalidImage
        }

        let outputDirectory = directory.appendingPathComponent("copied", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let fileName = "clipboard-image-\(formatter.string(from: Date())).png"
        let destination = outputDirectory.appendingPathComponent(fileName)
        try png.write(to: destination, options: .atomic)
        Logger.shared.log("Clipboard image written to \(destination.path)")
        return destination
    }
}
