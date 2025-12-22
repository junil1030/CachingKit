//
//  CachedAsyncImage.swift
//  CachingKit
//
//  Created by CachingKit on 2025-12-21.
//

import SwiftUI

/// SwiftUI view for loading cached images asynchronously
public struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    // MARK: - Properties

    private let url: URL?
    private let targetSize: CGSize
    private let cacheStrategy: CacheStrategy
    private let headers: [String: String]?
    private let cachingKit: CachingKit
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var loadTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Initialize CachedAsyncImage
    /// - Parameters:
    ///   - url: Image URL
    ///   - targetSize: Target size for resizing
    ///   - cacheStrategy: Caching strategy (default: .both)
    ///   - headers: Custom headers (optional)
    ///   - cachingKit: CachingKit instance (default: .shared)
    ///   - content: View builder for loaded image
    ///   - placeholder: Placeholder view while loading
    public init(
        url: URL?,
        targetSize: CGSize,
        cacheStrategy: CacheStrategy = .both,
        headers: [String: String]? = nil,
        cachingKit: CachingKit = .shared,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.targetSize = targetSize
        self.cacheStrategy = cacheStrategy
        self.headers = headers
        self.cachingKit = cachingKit
        self.content = content
        self.placeholder = placeholder
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if let loadedImage = loadedImage {
                content(Image(uiImage: loadedImage))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await loadImage()
        }
        .onDisappear {
            cancelLoad()
        }
    }

    // MARK: - Private Methods

    /// Load image asynchronously
    private func loadImage() async {
        // Cancel previous task
        cancelLoad()

        guard let url = url else {
            loadedImage = nil
            return
        }

        isLoading = true

        let task = Task {
            if let image = await cachingKit.loadImage(
                url: url,
                targetSize: targetSize,
                cacheStrategy: cacheStrategy,
                headers: headers
            ) {
                if !Task.isCancelled {
                    await MainActor.run {
                        loadedImage = image
                        isLoading = false
                    }
                }
            } else {
                if !Task.isCancelled {
                    await MainActor.run {
                        loadedImage = nil
                        isLoading = false
                    }
                }
            }
        }

        loadTask = task
        await task.value
    }

    /// Cancel image loading
    private func cancelLoad() {
        loadTask?.cancel()
        loadTask = nil
    }
}

// MARK: - Convenience Initializers

extension CachedAsyncImage where Placeholder == Color {
    /// Initialize with default gray placeholder
    public init(
        url: URL?,
        targetSize: CGSize,
        cacheStrategy: CacheStrategy = .both,
        headers: [String: String]? = nil,
        cachingKit: CachingKit = .shared,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.init(
            url: url,
            targetSize: targetSize,
            cacheStrategy: cacheStrategy,
            headers: headers,
            cachingKit: cachingKit,
            content: content,
            placeholder: { Color.gray.opacity(0.3) }
        )
    }
}

extension CachedAsyncImage where Content == Image {
    /// Initialize with default Image content
    public init(
        url: URL?,
        targetSize: CGSize,
        cacheStrategy: CacheStrategy = .both,
        headers: [String: String]? = nil,
        cachingKit: CachingKit = .shared,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.init(
            url: url,
            targetSize: targetSize,
            cacheStrategy: cacheStrategy,
            headers: headers,
            cachingKit: cachingKit,
            content: { image in image },
            placeholder: placeholder
        )
    }
}

extension CachedAsyncImage where Content == Image, Placeholder == Color {
    /// Initialize with default Image content and gray placeholder
    public init(
        url: URL?,
        targetSize: CGSize,
        cacheStrategy: CacheStrategy = .both,
        headers: [String: String]? = nil,
        cachingKit: CachingKit = .shared
    ) {
        self.init(
            url: url,
            targetSize: targetSize,
            cacheStrategy: cacheStrategy,
            headers: headers,
            cachingKit: cachingKit,
            content: { image in image },
            placeholder: { Color.gray.opacity(0.3) }
        )
    }
}
