//
//  HeaderProvider.swift
//  CachingKit
//
//  Created by CachingKit on 2025-12-23.
//

import Foundation

/// Protocol for dynamically providing HTTP headers
/// Implementations can inject authentication tokens or other dynamic headers
public protocol HeaderProvider: Sendable {
    /// Asynchronously provides headers to be added to network requests
    /// - Returns: Dictionary of header key-value pairs
    func headers() async -> [String: String]
}
