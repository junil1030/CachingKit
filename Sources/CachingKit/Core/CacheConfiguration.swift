//
//  CacheConfiguration.swift
//  CachingKit
//
//  Created by CachingKit on 2025-12-19.
//

import Foundation

/// Configuration object for CachingKit
public struct CacheConfiguration {
    /// Storage location provider
    public let storageProvider: StoragePathProvider

    /// Memory cache limit (bytes)
    public let memoryLimit: Int

    /// Disk cache limit (bytes)
    public let diskLimit: Int

    /// Time-to-live (seconds)
    public let ttl: TimeInterval

    /// Default headers to be added to all network requests (static)
    public let defaultHeaders: [String: String]

    /// Dynamic header provider (e.g., for authentication tokens)
    public let headerProvider: (any HeaderProvider)?

    /// Initialize with custom configuration
    /// - Parameters:
    ///   - storageProvider: Storage path provider (default: .default)
    ///   - memoryLimit: Memory limit in bytes (default: 25% of physical memory, max 150MB)
    ///   - diskLimit: Disk limit in bytes (default: 150MB)
    ///   - ttl: Time-to-live in seconds (default: 7 days)
    ///   - defaultHeaders: Default headers for all requests (default: empty)
    ///   - headerProvider: Dynamic header provider for authentication tokens (optional)
    public init(
        storageProvider: StoragePathProvider = .default,
        memoryLimit: Int? = nil,
        diskLimit: Int = 150 * 1024 * 1024,
        ttl: TimeInterval = 7 * 24 * 60 * 60,
        defaultHeaders: [String: String] = [:],
        headerProvider: (any HeaderProvider)? = nil
    ) {
        self.storageProvider = storageProvider
        self.memoryLimit = memoryLimit ?? {
            let physicalMemory = ProcessInfo.processInfo.physicalMemory
            return min(Int(Double(physicalMemory) * 0.25), 150 * 1024 * 1024)
        }()
        self.diskLimit = diskLimit
        self.ttl = ttl
        self.defaultHeaders = defaultHeaders
        self.headerProvider = headerProvider
    }
}
