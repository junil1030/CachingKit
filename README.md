# CachingKit

High-performance image caching library for iOS with dual-tier caching, ETag-based smart revalidation, and App Groups support.

## Features

- **Dual-Tier Caching**: Memory (NSCache) + Disk (FileManager) for optimal performance
- **Smart Revalidation**: ETag-based 304 Not Modified responses to save bandwidth
- **Hybrid Eviction**: LRU (70%) + LFU (30%) algorithm for intelligent cache management
- **Image Optimization**: Automatic downsampling and resizing to reduce memory usage
- **Thread-Safe**: Actor-based concurrency using Swift's modern async/await
- **App Groups Support**: Share cache across app extensions, widgets, and Live Activities
- **SwiftUI Support**: Native SwiftUI `CachedAsyncImage` view with async/await
- **Custom Headers**: Configure default and per-request HTTP headers for authenticated endpoints
- **Comprehensive Statistics**: Track hit rates, download stats, and cache size

## Requirements

- iOS 17.0+
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/YourUsername/CachingKit.git", from: "1.0.0")
]
```

Or in Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select the version

## Quick Start

### Basic Usage

```swift
import CachingKit

// Use default configuration
let image = await CachingKit.shared.loadImage(
    url: imageURL,
    targetSize: CGSize(width: 300, height: 300)
)
```

### UIImageView Extension

```swift
import CachingKit
import UIKit

// Load image with CachingKit
imageView.ck_setImage(
    with: imageURL,
    placeholder: UIImage(systemName: "photo"),
    targetSize: CGSize(width: 200, height: 200)
)

// Cancel loading
imageView.ck_cancelImageLoad()
```

### SwiftUI Integration

```swift
import CachingKit
import SwiftUI

// Basic usage
CachedAsyncImage(
    url: imageURL,
    targetSize: CGSize(width: 300, height: 300)
)
.frame(width: 300, height: 300)
.cornerRadius(8)

// Custom content and placeholder
CachedAsyncImage(
    url: imageURL,
    targetSize: CGSize(width: 200, height: 200)
) { image in
    image
        .resizable()
        .aspectRatio(contentMode: .fill)
} placeholder: {
    ProgressView()
}

// With custom headers
CachedAsyncImage(
    url: imageURL,
    targetSize: CGSize(width: 300, height: 300),
    headers: ["Authorization": "Bearer \(token)"]
)
```

### Custom Configuration

```swift
import CachingKit

// Configure with App Groups for widgets/Live Activities
let config = CacheConfiguration(
    storageProvider: .appGroups(identifier: "group.com.yourapp.shared"),
    memoryLimit: 200 * 1024 * 1024,  // 200MB
    diskLimit: 500 * 1024 * 1024,     // 500MB
    ttl: 14 * 24 * 60 * 60            // 14 days
)

// Initialize with custom configuration
let cachingKit = CachingKit(configuration: config)

// Or update shared instance
_ = CachingKit(configuration: config)
```

### Custom Headers

```swift
import CachingKit

// Configure default headers for all requests
var config = CacheConfiguration()
config.defaultHeaders = [
    "Authorization": "Bearer \(accessToken)",
    "User-Agent": "MyApp/1.0"
]
let cachingKit = CachingKit(configuration: config)

// Or add headers per request (merged with default headers)
let image = await CachingKit.shared.loadImage(
    url: imageURL,
    targetSize: CGSize(width: 300, height: 300),
    headers: ["X-Custom-Header": "value"]
)

// UIImageView with custom headers
imageView.ck_setImage(
    with: imageURL,
    targetSize: CGSize(width: 200, height: 200),
    headers: ["Authorization": "Bearer \(token)"]
)

// SwiftUI with custom headers
CachedAsyncImage(
    url: imageURL,
    targetSize: CGSize(width: 300, height: 300),
    headers: ["Authorization": "Bearer \(token)"]
)
```

### Storage Providers

CachingKit supports three storage providers:

```swift
// Default: Uses system caches directory
let config = CacheConfiguration(storageProvider: .default)

// App Groups: For sharing cache with widgets/extensions
let config = CacheConfiguration(
    storageProvider: .appGroups(identifier: "group.com.yourapp.shared")
)

// Custom: Use a specific directory
let customURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
let config = CacheConfiguration(storageProvider: .custom(url: customURL))
```

### Cache Strategies

```swift
// Memory + Disk (default)
imageView.ck_setImage(with: url, cacheStrategy: .both)

// Memory only (faster, but not persistent)
imageView.ck_setImage(with: url, cacheStrategy: .memoryOnly)

// Disk only (persistent, but slower access)
imageView.ck_setImage(with: url, cacheStrategy: .diskOnly)
```

### Cache Statistics

```swift
if let stats = await CachingKit.shared.getStatistics() {
    print("Memory hit rate: \(stats.memoryHitRate)")
    print("Disk hit rate: \(stats.diskHitRate)")
    print("ETag hit rate: \(stats.etagHitRate)")
    print("Cache size: \(stats.currentCacheSize / 1024 / 1024) MB")
}
```

### Clear Cache

```swift
// Clear memory cache only
CachingKit.shared.clearMemoryCache()

// Clear disk cache only
CachingKit.shared.clearDiskCache()

// Clear all caches
CachingKit.shared.clearAll()
```

## How It Works

### Dual-Tier Caching

1. **Memory Cache**: Fast access using NSCache with automatic eviction on memory warnings
2. **Disk Cache**: Persistent storage using FileManager with LRU+LFU hybrid eviction

When loading an image:
1. Check memory cache first (fastest)
2. If not in memory, check disk cache
3. If found on disk, promote to memory for faster subsequent access
4. If not in cache, download from network and cache

### ETag-Based Smart Revalidation

CachingKit uses HTTP ETags to minimize bandwidth usage:

- Images are cached with their ETag (if provided by server)
- After TTL expires, CachingKit sends `If-None-Match` header
- If server responds with `304 Not Modified`, existing cache is valid
- Only downloads new data when image has changed

**Estimated bandwidth savings**: ~200KB per valid cache revalidation

### Hybrid Eviction Policy

When disk cache exceeds the limit, CachingKit uses a hybrid LRU+LFU algorithm:

- **Score** = (Recency × 0.7) + (Frequency × 0.3)
- Items with lowest score are evicted first
- Balances between recent and frequently accessed images

### Image Optimization

- **Downsampling**: Images are downsampled during decode to save memory
- **Resizing**: Automatically resized to target size
- **Example**: A 750×1125 image resized to 300×450 uses ~1/6 the memory

## Architecture

```
┌─────────────────────────────────────┐
│         CachingKit (Public API)      │
└──────────────┬──────────────────────┘
               │
      ┌────────┴────────┐
      │  CacheManager   │ (Actor)
      └────────┬────────┘
          ┌────┴────┐
    ┌─────▼─────┐ ┌▼──────────────┐
    │  Memory   │ │   Disk Cache   │
    │   Cache   │ │  + Metadata    │
    │ (NSCache) │ │ (FileManager)  │
    └───────────┘ └─────┬──────────┘
                        │
                  ┌─────▼──────┐
                  │  LRU+LFU   │
                  │  Eviction  │
                  └────────────┘
```

## Performance

### Memory Usage

- Default memory limit: 25% of physical memory (max 150MB)
- Images are downsampled before storing
- Automatic cleanup on memory warnings

### Disk Usage

- Default disk limit: 150MB
- Automatic cleanup using hybrid LRU+LFU algorithm
- Metadata stored in single JSON file

### Network Efficiency

- ETag-based revalidation saves bandwidth
- 304 responses avoid full image downloads
- Duplicate request prevention

## License

MIT License

Copyright (c) 2025 CachingKit

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
# CachingKit
