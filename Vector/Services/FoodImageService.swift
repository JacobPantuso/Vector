import SwiftUI
import UIKit
import ImagePlayground

/// Generates and caches stylized AI images of logged foods using the Image Playground engine.
/// Falls back silently (no image) when generation is unsupported or unavailable.
@MainActor
@Observable
final class FoodImageService {
    static let shared = FoodImageService()

    private(set) var images: [UUID: UIImage] = [:]
    private var inFlight: Set<UUID> = []

    private var directory: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FoodImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func fileURL(_ id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).png")
    }

    /// Returns a cached image (memory or disk) if present.
    func image(for id: UUID) -> UIImage? {
        if let img = images[id] { return img }
        if let data = try? Data(contentsOf: fileURL(id)), let img = UIImage(data: data) {
            images[id] = img
            return img
        }
        return nil
    }

    /// Generates an image for the entry if one isn't already cached or in flight.
    func generate(for entry: FoodLogEntry) {
        let id = entry.id
        guard image(for: id) == nil, !inFlight.contains(id) else { return }
        inFlight.insert(id)
        let name = entry.name
        Task { await generateImage(name: name, id: id) }
    }

    private func generateImage(name: String, id: UUID) async {
        defer { inFlight.remove(id) }
        do {
            let creator = try await ImageCreator()
            let concept = ImagePlaygroundConcept.text("An appetizing, beautifully plated dish of \(name), food photography")
            for try await created in creator.images(for: [concept], style: .illustration, limit: 1) {
                let uiImage = UIImage(cgImage: created.cgImage)
                images[id] = uiImage
                if let data = uiImage.pngData() {
                    try? data.write(to: fileURL(id))
                }
                break
            }
        } catch {
            // notSupported / unavailable / failure — leave uncached so the UI shows its fallback.
        }
    }
}
