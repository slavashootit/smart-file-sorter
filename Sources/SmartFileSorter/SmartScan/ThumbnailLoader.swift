import Foundation
import QuickLookThumbnailing
import Cocoa

private final class ThreadSafeCache: @unchecked Sendable {
    private let cache = NSCache<NSURL, NSImage>()
    
    init(countLimit: Int) {
        cache.countLimit = countLimit
    }
    
    func object(forKey key: NSURL) -> NSImage? {
        cache.object(forKey: key)
    }
    
    func setObject(_ obj: NSImage, forKey key: NSURL) {
        cache.setObject(obj, forKey: key)
    }
    
    func removeAllObjects() {
        cache.removeAllObjects()
    }
}

@MainActor
public final class ThumbnailLoader: ObservableObject {
    public static let shared = ThumbnailLoader()
    
    private let cache = ThreadSafeCache(countLimit: 500)
    public private(set) var generatorCallCount = 0
    
    private init() {}
    
    public func loadThumbnail(for url: URL, size: CGFloat) async -> NSImage? {
        let cacheKey = url.appendingPathComponent("size-\(Int(size))") as NSURL
        
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }
        
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: size, height: size),
            scale: scale,
            representationTypes: .thumbnail
        )
        
        generatorCallCount += 1
        
        let cacheRef = cache
        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, error in
                if let nsImage = representation?.nsImage {
                    cacheRef.setObject(nsImage, forKey: cacheKey)
                    continuation.resume(returning: nsImage)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    public func clearCache() {
        cache.removeAllObjects()
        generatorCallCount = 0
    }
}
