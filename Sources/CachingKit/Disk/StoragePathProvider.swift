//
//  StoragePathProvider.swift
//  CachingKit
//
//  Created by CachingKit on 2025-12-19.
//

import Foundation

/// Protocol for providing storage paths
public protocol StoragePathProviderProtocol {
    /// Base cache directory URL
    var baseCacheDirectory: URL? { get }
}

/// Concrete storage path providers
public enum StoragePathProvider: StoragePathProviderProtocol {
    /// Use system caches directory (default)
    case `default`

    /// Use App Groups container
    case appGroups(identifier: String)

    /// Use custom directory
    case custom(url: URL)

    public var baseCacheDirectory: URL? {
        switch self {
        case .default:
            return FileManager.default
                .urls(for: .cachesDirectory, in: .userDomainMask).first?
                .appendingPathComponent("CachingKit", isDirectory: true)

        case .appGroups(let identifier):
            guard let containerURL = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
                print("[CachingKit] ⚠️ App Groups '\(identifier)' not found, using default")
                return StoragePathProvider.default.baseCacheDirectory
            }
            return containerURL
                .appendingPathComponent("Library/Caches/CachingKit", isDirectory: true)

        case .custom(let url):
            return url
        }
    }
}
