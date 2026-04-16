import Foundation
import AppKit
import Observation

@Observable
@MainActor
final class ObsidianStore {
    static let shared = ObsidianStore()

    private let bookmarkKey = "minimax.obsidian.bookmark"
    var vaultURL: URL? = nil

    private init() {
        resolveBookmark()
    }

    private func resolveBookmark() {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { vaultURL = nil; return }
        var stale = false
        if let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) {
            if url.startAccessingSecurityScopedResource() {
                vaultURL = url
            } else {
                vaultURL = nil
            }
        } else {
            vaultURL = nil
        }
    }

    func selectVault() async {
        await MainActor.run {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = "Choose"
            let resp = panel.runModal()
            guard resp == .OK, let url = panel.url else { return }
            do {
                let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(data, forKey: bookmarkKey)
                _ = url.startAccessingSecurityScopedResource()
                vaultURL = url
            } catch {
                print("[ObsidianStore] bookmark error: \(error)")
            }
        }
    }
}
