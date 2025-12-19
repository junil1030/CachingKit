//
//  UIImageView+CachingKit.swift
//  CachingKit
//
//  Created by CachingKit on 2025-12-19.
//

import UIKit

// MARK: - Associated Keys

private var ck_imageLoadTaskKey: UInt8 = 0

// MARK: - UIImageView Extension

extension UIImageView {
    // MARK: - Associated Object

    /// Currently running image load task
    private var ck_imageLoadTask: Task<Void, Never>? {
        get {
            return objc_getAssociatedObject(self, &ck_imageLoadTaskKey) as? Task<Void, Never>
        }
        set {
            objc_setAssociatedObject(self, &ck_imageLoadTaskKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    // MARK: - Public Methods

    /// Load image using CachingKit
    /// - Parameters:
    ///   - url: Image URL
    ///   - placeholder: Placeholder image (shown while loading)
    ///   - targetSize: Target size (uses bounds.size if nil)
    ///   - cacheStrategy: Caching strategy (default: .both)
    ///   - cachingKit: CachingKit instance (default: .shared)
    public func ck_setImage(
        with url: URL?,
        placeholder: UIImage? = nil,
        targetSize: CGSize? = nil,
        cacheStrategy: CacheStrategy = .both,
        cachingKit: CachingKit = .shared
    ) {
        // Cancel previous task
        ck_cancelImageLoad()

        // Set placeholder
        image = placeholder

        // Check URL
        guard let url = url else {
            return
        }

        // Determine target size (use bounds.size if nil)
        let finalTargetSize: CGSize
        if let targetSize = targetSize, targetSize.width > 0, targetSize.height > 0 {
            finalTargetSize = targetSize
        } else if bounds.size.width > 0, bounds.size.height > 0 {
            finalTargetSize = bounds.size
        } else {
            // If bounds not determined yet, use default size
            finalTargetSize = CGSize(width: 300, height: 300)
        }

        // Start new task
        let task = Task { @MainActor in
            // Check if task was cancelled
            guard !Task.isCancelled else {
                return
            }

            // Load image with CachingKit
            if let loadedImage = await cachingKit.loadImage(
                url: url,
                targetSize: finalTargetSize,
                cacheStrategy: cacheStrategy
            ) {
                // Check if task was cancelled after load
                guard !Task.isCancelled else {
                    return
                }

                // Set image
                self.image = loadedImage
            }
        }

        // Store task
        ck_imageLoadTask = task
    }

    /// Cancel currently running image load
    public func ck_cancelImageLoad() {
        ck_imageLoadTask?.cancel()
        ck_imageLoadTask = nil
    }
}
