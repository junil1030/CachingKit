//
//  CachingKitError.swift
//  CachingKit
//
//  Created by CachingKit on 2025-12-19.
//

import Foundation

/// Errors that can occur in CachingKit
public enum CachingKitError: Error {
    /// Invalid storage path
    case invalidStoragePath

    /// Cache initialization failed
    case initializationFailed(Error)

    /// Network error
    case networkError(Error)

    /// Disk write error
    case diskWriteError(Error)
}
