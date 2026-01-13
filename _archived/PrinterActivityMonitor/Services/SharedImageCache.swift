import Foundation
import UIKit

/// Manages shared image caching for Live Activities
/// Images are stored in App Group container so the widget extension can access them
class SharedImageCache {
    static let shared = SharedImageCache()

    private let appGroupIdentifier = "group.com.printeractivitymonitor.shared"
    private let coverImageFileName = "cover_image.png"

    private var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    private var coverImageURL: URL? {
        containerURL?.appendingPathComponent(coverImageFileName)
    }

    /// Downloads and caches the cover image from Home Assistant
    /// - Parameters:
    ///   - urlString: The full URL to the cover image
    ///   - accessToken: The Home Assistant access token for authentication
    /// - Returns: The local file URL if successful, nil otherwise
    @discardableResult
    func cacheCoverImage(from urlString: String, accessToken: String) async -> URL? {
        guard let url = URL(string: urlString),
              let destinationURL = coverImageURL else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            // Verify it's valid image data
            guard UIImage(data: data) != nil else {
                return nil
            }

            // Write to shared container
            try data.write(to: destinationURL)

            return destinationURL
        } catch {
            print("SharedImageCache: Failed to cache image - \(error)")
            return nil
        }
    }

    /// Gets the cached cover image URL for use in Live Activities
    /// - Returns: The file URL if a cached image exists
    func getCachedCoverImageURL() -> URL? {
        guard let url = coverImageURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }

    /// Gets the cached cover image URL as a string for ActivityKit
    func getCachedCoverImageURLString() -> String? {
        getCachedCoverImageURL()?.absoluteString
    }

    /// Clears the cached cover image
    func clearCachedCoverImage() {
        guard let url = coverImageURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Checks if a cached cover image exists
    var hasCachedCoverImage: Bool {
        guard let url = coverImageURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
}
