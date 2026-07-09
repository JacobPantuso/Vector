import Foundation

/// Persists the user's profile photo as a JPEG in the documents directory.
enum ProfilePhotoStore {
    private static var url: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("profilePhoto.jpg")
    }
    static func save(_ data: Data) { try? data.write(to: url) }
    static func load() -> Data? { try? Data(contentsOf: url) }
    static func clear() { try? FileManager.default.removeItem(at: url) }
}
