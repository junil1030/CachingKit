//
//  CacheMetadata.swift
//  CurtainCall
//
//  Created by 서준일 on 12/7/25.
//

import Foundation

/// 캐시 메타데이터
public struct CacheMetadata: Codable {
    // MARK: - Properties

    /// 원본 URL
    let url: String

    /// ETag 값 (서버에서 제공하는 경우)
    var etag: String?

    /// 최초 캐시 저장 시각
    var cachedDate: Date

    /// 마지막 ETag 검증 시각
    var lastValidated: Date

    /// 접근 횟수 (LFU용)
    var accessCount: Int

    /// 마지막 접근 시각 (LRU용)
    var lastAccessTime: Date

    /// 파일 크기 (bytes)
    var fileSize: Int

    /// 리사이징된 타겟 크기
    var targetSize: CGSize

    // MARK: - Initialization

    init(
        url: String,
        etag: String? = nil,
        cachedDate: Date = Date(),
        lastValidated: Date = Date(),
        accessCount: Int = 1,
        lastAccessTime: Date = Date(),
        fileSize: Int = 0,
        targetSize: CGSize
    ) {
        self.url = url
        self.etag = etag
        self.cachedDate = cachedDate
        self.lastValidated = lastValidated
        self.accessCount = accessCount
        self.lastAccessTime = lastAccessTime
        self.fileSize = fileSize
        self.targetSize = targetSize
    }

    // MARK: - Methods

    /// 접근 기록 (카운트 증가 및 시각 갱신)
    mutating func recordAccess() {
        accessCount += 1
        lastAccessTime = Date()
    }

    /// ETag 검증 완료 (lastValidated 갱신)
    mutating func markValidated() {
        lastValidated = Date()
    }

    /// TTL 만료 여부 확인
    func isTTLExpired(ttl: TimeInterval) -> Bool {
        let elapsed = Date().timeIntervalSince(cachedDate)
        return elapsed > ttl
    }

    /// LRU+LFU 혼합 점수 계산
    /// - Parameter maxAccessCount: 현재 캐시 중 최대 접근 횟수
    /// - Returns: 0.0 ~ 1.0 사이의 점수 (높을수록 유지)
    func calculateScore(maxAccessCount: Int) -> Double {
        // 최근성 점수 (0.0 ~ 1.0)
        // 최근일수록 높은 점수
        let maxAge: TimeInterval = 7 * 24 * 60 * 60 // 7일
        let age = Date().timeIntervalSince(lastAccessTime)
        let recencyScore = max(0, 1.0 - (age / maxAge))

        // 빈도 점수 (0.0 ~ 1.0)
        let frequencyScore = maxAccessCount > 0
            ? min(Double(accessCount) / Double(maxAccessCount), 1.0)
            : 0.0

        // LRU 70% + LFU 30%
        return (recencyScore * 0.7) + (frequencyScore * 0.3)
    }
}

// MARK: - CGSize Codable Extension

extension CGSize: Codable {
    enum CodingKeys: String, CodingKey {
        case width
        case height
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let width = try container.decode(CGFloat.self, forKey: .width)
        let height = try container.decode(CGFloat.self, forKey: .height)
        self.init(width: width, height: height)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
    }
}
