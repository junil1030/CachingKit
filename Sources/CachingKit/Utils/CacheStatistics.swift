//
//  CacheStatistics.swift
//  CurtainCall
//
//  Created by 서준일 on 12/7/25.
//

import Foundation

/// 캐시 통계
public struct CacheStatistics {
    // MARK: - Properties

    /// 메모리 캐시 히트율 (0.0 ~ 1.0)
    let memoryHitRate: Double

    /// 디스크 캐시 히트율 (0.0 ~ 1.0)
    let diskHitRate: Double

    /// ETag 히트율 (304 응답 비율, 0.0 ~ 1.0)
    let etagHitRate: Double

    /// 총 다운로드 횟수
    let totalDownloads: Int

    /// 총 다운로드 바이트
    let totalBytesDownloaded: Int

    /// ETag로 절약한 바이트
    let totalBytesSaved: Int

    /// 현재 캐시 크기 (bytes)
    let currentCacheSize: Int

    // MARK: - Computed Properties

    /// 메모리 히트율 (퍼센트)
    var memoryHitRatePercent: Double {
        return memoryHitRate * 100
    }

    /// 디스크 히트율 (퍼센트)
    var diskHitRatePercent: Double {
        return diskHitRate * 100
    }

    /// ETag 히트율 (퍼센트)
    var etagHitRatePercent: Double {
        return etagHitRate * 100
    }

    /// 총 다운로드 크기 (MB)
    var downloadedMB: Double {
        return Double(totalBytesDownloaded) / (1024 * 1024)
    }

    /// 절약한 크기 (MB)
    var savedMB: Double {
        return Double(totalBytesSaved) / (1024 * 1024)
    }

    /// 현재 캐시 크기 (MB)
    var cacheSizeMB: Double {
        return Double(currentCacheSize) / (1024 * 1024)
    }

    // MARK: - Methods

    /// 통계를 문자열로 출력
    func description() -> String {
        return """
        === CustomImageCache 통계 ===
        메모리 히트율: \(String(format: "%.1f%%", memoryHitRatePercent))
        디스크 히트율: \(String(format: "%.1f%%", diskHitRatePercent))
        ETag 히트율: \(String(format: "%.1f%%", etagHitRatePercent))
        총 다운로드: \(totalDownloads)회
        다운로드 크기: \(String(format: "%.2f MB", downloadedMB))
        절약한 크기: \(String(format: "%.2f MB", savedMB))
        현재 캐시: \(String(format: "%.2f MB", cacheSizeMB))
        """
    }
}
