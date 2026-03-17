import AppKit
import Foundation

@MainActor
final class PasteWorkflow {
    private let resolver = TargetDirectoryResolver()

    func handlePaste(completion: @escaping (Result<URL, Error>) -> Void) {
        do {
            let directory = try resolver.resolveDirectory()
            Logger.shared.log("Resolved target directory: \(directory.path)")
            let savedURL = try ClipboardImageSaver.shared.saveClipboardImage(into: directory)
            completion(.success(savedURL))
        } catch TargetDirectoryResolver.DirectoryError.notFound {
            Logger.shared.log("Could not resolve target directory automatically; prompting user")
            promptForDirectory(completion: completion)
        } catch {
            Logger.shared.log("Unexpected paste workflow error: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }

    private func promptForDirectory(completion: @escaping (Result<URL, Error>) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder where pasted images should be copied."
        panel.prompt = "Use Folder"

        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK, let selected = panel.url else {
                Logger.shared.log("Folder selection canceled")
                completion(.failure(TargetDirectoryResolver.DirectoryError.notFound))
                return
            }

            do {
                Logger.shared.log("User selected target directory: \(selected.path)")
                let savedURL = try ClipboardImageSaver.shared.saveClipboardImage(into: selected)
                completion(.success(savedURL))
            } catch {
                Logger.shared.log("Saving to user-selected directory failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
}
