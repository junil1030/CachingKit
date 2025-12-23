//
//  CachingKit.swift
//  CachingKit
//
//  Created by CachingKit on 2025-12-19.
//

import UIKit

/// CachingKit - High-performance image caching library
public final class CachingKit {
    // MARK: - Singleton

    public static let shared = CachingKit()

    // MARK: - Properties

    /// Cache manager
    private var cacheManager: CacheManager?

    /// Network loader
    private let networkLoader: NetworkLoader

    /// Configuration
    private let configuration: CacheConfiguration

    // MARK: - Initialization

    /// Initialize with default configuration
    private init() {
        self.configuration = CacheConfiguration()
        self.networkLoader = NetworkLoader()

        do {
            self.cacheManager = try CacheManager(configuration: configuration)
        } catch {
        }
    }

    /// Initialize with custom configuration
    public init(configuration: CacheConfiguration) {
        self.configuration = configuration
        self.networkLoader = NetworkLoader()

        do {
            self.cacheManager = try CacheManager(configuration: configuration)
        } catch {
        }
    }

    // MARK: - Public Methods

    /// Load image from cache or network
    /// - Parameters:
    ///   - url: Image URL
    ///   - targetSize: Target size for resizing
    ///   - cacheStrategy: Caching strategy (default: .both)
    ///   - headers: Custom headers (optional, merged with defaultHeaders and headerProvider)
    /// - Returns: Loaded image or nil
    public func loadImage(url: URL, targetSize: CGSize, cacheStrategy: CacheStrategy = .both, headers: [String: String]? = nil) async -> UIImage? {
        guard let cacheManager = cacheManager else {
            return nil
        }

        // Merge headers in priority order: defaultHeaders < headerProvider < custom headers
        var mergedHeaders = configuration.defaultHeaders

        // Add dynamic headers from headerProvider
        if let headerProvider = configuration.headerProvider {
            let dynamicHeaders = await headerProvider.headers()
            mergedHeaders.merge(dynamicHeaders) { (_, new) in new }
        }

        // Add custom headers (highest priority)
        if let headers = headers {
            mergedHeaders.merge(headers) { (_, new) in new }
        }

        let finalHeaders = mergedHeaders.isEmpty ? nil : mergedHeaders

        // Generate cache key
        let cacheKey = generateCacheKey(url: url, size: targetSize)

        // 1. Check cache (memory → disk)
        if let cachedImage = await cacheManager.getImage(key: cacheKey) {
            return cachedImage
        }

        // 2. Check metadata (ETag and TTL)
        let metadata = await cacheManager.getMetadata(key: cacheKey)
        let existingETag = metadata?.etag
        let isTTLExpired = await cacheManager.isTTLExpired(key: cacheKey)

        // 3. Download from network
        do {
            // If TTL expired and has ETag, try revalidation
            let result = try await networkLoader.downloadImage(
                url: url,
                etag: isTTLExpired ? existingETag : nil,
                headers: finalHeaders
            )

            switch result {
            case .success(let data, let newETag):
                // New image downloaded successfully
                // Downsample for memory efficiency
                guard let image = ImageResizer.downsample(data: data, targetSize: targetSize) else {
                    return nil
                }

                // Save to cache based on strategy
                let newMetadata = CacheMetadata(
                    url: url.absoluteString,
                    etag: newETag,
                    targetSize: targetSize
                )

                switch cacheStrategy {
                case .memoryOnly:
                    await cacheManager.setImageMemoryOnly(key: cacheKey, image: image, metadata: newMetadata)
                case .diskOnly:
                    await cacheManager.setImageDiskOnly(key: cacheKey, image: image, metadata: newMetadata)
                case .both:
                    await cacheManager.setImage(key: cacheKey, image: image, metadata: newMetadata)
                }

                return image

            case .notModified:
                // 304 response - existing cache is valid
                // Update lastValidated in metadata
                if var existingMetadata = metadata {
                    existingMetadata.markValidated()
                    await cacheManager.updateMetadata(key: cacheKey, metadata: existingMetadata)
                }

                // Reload from disk cache
                if let cachedImage = await cacheManager.getImage(key: cacheKey) {
                    return cachedImage
                }
                return nil
            }

        } catch {
            return nil
        }
    }

    /// Save image manually
    /// - Parameters:
    ///   - image: Image to save
    ///   - url: Image URL
    ///   - targetSize: Target size
    ///   - etag: ETag (optional)
    ///   - cacheStrategy: Caching strategy (default: .both)
    public func saveImage(
        image: UIImage,
        url: URL,
        targetSize: CGSize,
        etag: String? = nil,
        cacheStrategy: CacheStrategy = .both
    ) async {
        guard let cacheManager = cacheManager else { return }

        let cacheKey = generateCacheKey(url: url, size: targetSize)
        let metadata = CacheMetadata(
            url: url.absoluteString,
            etag: etag,
            targetSize: targetSize
        )

        switch cacheStrategy {
        case .memoryOnly:
            await cacheManager.setImageMemoryOnly(key: cacheKey, image: image, metadata: metadata)
        case .diskOnly:
            await cacheManager.setImageDiskOnly(key: cacheKey, image: image, metadata: metadata)
        case .both:
            await cacheManager.setImage(key: cacheKey, image: image, metadata: metadata)
        }
    }

    /// Clear memory cache
    public func clearMemoryCache() {
        Task {
            await cacheManager?.clearMemoryCache()
        }
    }

    /// Clear disk cache
    public func clearDiskCache() {
        Task {
            await cacheManager?.clearDiskCache()
        }
    }

    /// Clear all caches
    public func clearAll() {
        Task {
            await cacheManager?.clearAll()
        }
    }

    /// Get cache statistics
    /// - Returns: Cache statistics
    public func getStatistics() async -> CacheStatistics? {
        guard let cacheStats = await cacheManager?.getStatistics() else {
            return nil
        }

        let networkStats = await networkLoader.getStatistics()
        let etagHitRate = await networkLoader.getETagHitRate()

        return CacheStatistics(
            memoryHitRate: cacheStats.memoryHitRate,
            diskHitRate: cacheStats.diskHitRate,
            etagHitRate: etagHitRate,
            totalDownloads: networkStats.downloads,
            totalBytesDownloaded: networkStats.downloaded,
            totalBytesSaved: networkStats.saved,
            currentCacheSize: cacheStats.cacheSize
        )
    }

    // MARK: - Private Methods

    /// Generate cache key
    /// - Parameters:
    ///   - url: Image URL
    ///   - size: Target size
    /// - Returns: Hashed cache key
    private func generateCacheKey(url: URL, size: CGSize) -> String {
        let sizeString = "\(Int(size.width))x\(Int(size.height))"
        let key = "\(url.absoluteString)_\(sizeString)"
        return key.sha256
    }
}
