//
//  View+CachingKit.swift
//  CachingKit
//
//  Created by CachingKit on 2025-12-21.
//

import SwiftUI

// MARK: - View Extension for CachingKit

extension View {
    /// Apply cached image as background
    /// - Parameters:
    ///   - url: Image URL
    ///   - targetSize: Target size for resizing
    ///   - cacheStrategy: Caching strategy (default: .both)
    ///   - headers: Custom headers (optional)
    ///   - cachingKit: CachingKit instance (default: .shared)
    /// - Returns: View with cached image background
    public func cachedImageBackground(
        url: URL?,
        targetSize: CGSize,
        cacheStrategy: CacheStrategy = .both,
        headers: [String: String]? = nil,
        cachingKit: CachingKit = .shared
    ) -> some View {
        self.background(
            CachedAsyncImage(
                url: url,
                targetSize: targetSize,
                cacheStrategy: cacheStrategy,
                headers: headers,
                cachingKit: cachingKit
            ) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.3)
            }
        )
    }
}
