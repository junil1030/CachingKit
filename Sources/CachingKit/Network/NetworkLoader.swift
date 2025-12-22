//
//  NetworkLoader.swift
//  CurtainCall
//
//  Created by 서준일 on 12/7/25.
//

import Foundation

/// 네트워크 이미지 로더
actor NetworkLoader {
    // MARK: - Properties

    /// URLSession
    private let session: URLSession

    /// 진행 중인 Task들 (중복 요청 방지)
    private var ongoingTasks: [URL: Task<ImageDownloadResult, Error>] = [:]

    /// 통계
    private var totalDownloads: Int = 0
    private var etagHits: Int = 0 // 304 응답 횟수
    private var totalBytesDownloaded: Int = 0
    private var totalBytesSaved: Int = 0 // ETag로 절약한 바이트

    // MARK: - Initialization

    init(configuration: URLSessionConfiguration = .default) {
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60

        self.session = URLSession(configuration: configuration)

    }

    // MARK: - Public Methods

    /// 이미지 다운로드
    /// - Parameters:
    ///   - url: 이미지 URL
    ///   - etag: 기존 ETag (있으면 If-None-Match 헤더 추가)
    ///   - headers: 커스텀 헤더 (optional)
    /// - Returns: 다운로드 결과
    func downloadImage(url: URL, etag: String? = nil, headers: [String: String]? = nil) async throws -> ImageDownloadResult {
        // 이미 진행 중인 요청이 있으면 그것을 기다림 (중복 방지)
        if let ongoingTask = ongoingTasks[url] {
            return try await ongoingTask.value
        }

        // 새 Task 생성
        let task = Task<ImageDownloadResult, Error> {
            defer {
                ongoingTasks.removeValue(forKey: url)
            }

            return try await performDownload(url: url, etag: etag, headers: headers)
        }

        ongoingTasks[url] = task
        return try await task.value
    }

    /// 다운로드 취소
    /// - Parameter url: 취소할 URL
    func cancelDownload(url: URL) {
        ongoingTasks[url]?.cancel()
        ongoingTasks.removeValue(forKey: url)
    }

    /// 모든 다운로드 취소
    func cancelAllDownloads() {
        for task in ongoingTasks.values {
            task.cancel()
        }
        ongoingTasks.removeAll()
    }

    /// 통계 가져오기
    /// - Returns: (전체 다운로드, ETag 적중, 다운로드 바이트, 절약 바이트)
    func getStatistics() -> (downloads: Int, etagHits: Int, downloaded: Int, saved: Int) {
        return (totalDownloads, etagHits, totalBytesDownloaded, totalBytesSaved)
    }

    /// ETag 적중률
    /// - Returns: 0.0 ~ 1.0
    func getETagHitRate() -> Double {
        guard totalDownloads > 0 else { return 0.0 }
        return Double(etagHits) / Double(totalDownloads)
    }

    /// 통계 초기화
    func resetStatistics() {
        totalDownloads = 0
        etagHits = 0
        totalBytesDownloaded = 0
        totalBytesSaved = 0
    }

    // MARK: - Private Methods

    /// 실제 다운로드 수행
    /// - Parameters:
    ///   - url: 이미지 URL
    ///   - etag: 기존 ETag
    ///   - headers: 커스텀 헤더
    /// - Returns: 다운로드 결과
    private func performDownload(url: URL, etag: String?, headers: [String: String]?) async throws -> ImageDownloadResult {
        var request = URLRequest(url: url)

        // 커스텀 헤더 추가
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        // ETag가 있으면 If-None-Match 헤더 추가
        if let etag = etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        totalDownloads += 1

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ImageCacheNetworkError.invalidResponse
            }


            switch httpResponse.statusCode {
            case 200:
                // 새 이미지 다운로드 성공
                let newETag = httpResponse.value(forHTTPHeaderField: "ETag")
                totalBytesDownloaded += data.count


                return .success(data: data, etag: newETag)

            case 304:
                // Not Modified - 캐시 유효
                etagHits += 1

                // 예상 절약 바이트 (평균 이미지 크기로 추정: 200KB)
                let estimatedSavedBytes = 200 * 1024
                totalBytesSaved += estimatedSavedBytes


                return .notModified

            case 404:
                throw ImageCacheNetworkError.notFound

            case 500...599:
                throw ImageCacheNetworkError.serverError(httpResponse.statusCode)

            default:
                throw ImageCacheNetworkError.httpError(httpResponse.statusCode)
            }

        } catch let error as URLError {
            if error.code == .cancelled {
                throw ImageCacheNetworkError.cancelled
            }
            throw ImageCacheNetworkError.networkError(error)
        } catch {
            throw error
        }
    }
}

// MARK: - ImageDownloadResult

/// 이미지 다운로드 결과
enum ImageDownloadResult {
    /// 성공 (새 데이터 + ETag)
    case success(data: Data, etag: String?)

    /// Not Modified (304) - 캐시 유효
    case notModified
}

// MARK: - ImageCacheNetworkError

/// 이미지 캐시 네트워크 에러
enum ImageCacheNetworkError: LocalizedError {
    case invalidResponse
    case notFound
    case serverError(Int)
    case httpError(Int)
    case networkError(URLError)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "유효하지 않은 응답"
        case .notFound:
            return "이미지를 찾을 수 없음 (404)"
        case .serverError(let code):
            return "서버 에러 (\(code))"
        case .httpError(let code):
            return "HTTP 에러 (\(code))"
        case .networkError(let error):
            return "네트워크 에러: \(error.localizedDescription)"
        case .cancelled:
            return "요청 취소됨"
        }
    }
}
