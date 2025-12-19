//
//  ImageResizer.swift
//  CurtainCall
//
//  Created by 서준일 on 12/7/25.
//

import UIKit

/// 이미지 리사이징 유틸리티
struct ImageResizer {
    // MARK: - Public Methods

    /// 이미지를 타겟 크기로 리사이징
    /// - Parameters:
    ///   - image: 원본 이미지
    ///   - targetSize: 목표 크기
    /// - Returns: 리사이징된 이미지 (리사이징 불필요 시 원본 반환)
    static func resize(image: UIImage, targetSize: CGSize) -> UIImage {
        let originalSize = image.size
        let originalMemorySize = estimateMemorySize(of: image)

        // 리사이징 필요 여부 확인
        guard shouldResize(originalSize: originalSize, targetSize: targetSize) else {
            return image
        }

        // 실제 리사이징 크기 계산 (aspect ratio 유지)
        let resizedSize = calculateResizedSize(originalSize: originalSize, targetSize: targetSize)

        // UIGraphicsImageRenderer로 리사이징
        let renderer = UIGraphicsImageRenderer(size: resizedSize)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: resizedSize))
        }

        let resizedMemorySize = estimateMemorySize(of: resizedImage)
        let savedBytes = originalMemorySize - resizedMemorySize
        let savedPercentage = (1.0 - Double(resizedMemorySize) / Double(originalMemorySize)) * 100


        return resizedImage
    }

    /// 이미지를 다운샘플링 (메모리 효율적)
    /// - Parameters:
    ///   - data: 이미지 데이터
    ///   - targetSize: 목표 크기
    /// - Returns: 다운샘플링된 이미지
    static func downsample(data: Data, targetSize: CGSize) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary

        guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
            return nil
        }

        // 원본 이미지 크기 확인
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let originalWidth = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let originalHeight = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
            return UIImage(data: data)
        }

        let originalSize = CGSize(width: originalWidth, height: originalHeight)

        // 리사이징 필요 여부 확인
        guard shouldResize(originalSize: originalSize, targetSize: targetSize) else {
            return UIImage(data: data)
        }

        // 다운샘플링 크기 계산
        let resizedSize = calculateResizedSize(originalSize: originalSize, targetSize: targetSize)
        let maxDimensionInPixels = max(resizedSize.width, resizedSize.height) * UIScreen.main.scale

        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as CFDictionary

        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return UIImage(data: data)
        }

        let resultImage = UIImage(cgImage: downsampledImage)

        // 원본을 메모리에 로드했을 때의 예상 크기 (width * height * 4 bytes per pixel for RGBA)
        let originalMemorySize = Int(originalWidth * originalHeight * 4)
        let downsampledMemorySize = estimateMemorySize(of: resultImage)
        let savedBytes = originalMemorySize - downsampledMemorySize
        let savedPercentage = (1.0 - Double(downsampledMemorySize) / Double(originalMemorySize)) * 100


        return resultImage
    }

    // MARK: - Private Methods

    /// 리사이징 필요 여부 확인
    /// - Parameters:
    ///   - originalSize: 원본 크기
    ///   - targetSize: 목표 크기
    /// - Returns: 리사이징 필요 여부
    private static func shouldResize(originalSize: CGSize, targetSize: CGSize) -> Bool {
        // targetSize가 zero면 리사이징 불필요
        guard targetSize.width > 0 && targetSize.height > 0 else {
            return false
        }

        // 원본이 타겟보다 작거나 같으면 리사이징 불필요
        if originalSize.width <= targetSize.width && originalSize.height <= targetSize.height {
            return false
        }

        return true
    }

    /// 리사이징 크기 계산 (aspect ratio 유지)
    /// - Parameters:
    ///   - originalSize: 원본 크기
    ///   - targetSize: 목표 크기
    /// - Returns: 계산된 리사이징 크기
    private static func calculateResizedSize(originalSize: CGSize, targetSize: CGSize) -> CGSize {
        let widthRatio = targetSize.width / originalSize.width
        let heightRatio = targetSize.height / originalSize.height

        // 작은 비율을 사용 (이미지가 타겟 영역에 완전히 들어가도록)
        let ratio = min(widthRatio, heightRatio)

        let newWidth = originalSize.width * ratio
        let newHeight = originalSize.height * ratio

        return CGSize(width: newWidth, height: newHeight)
    }

    /// 이미지의 메모리 크기 추정
    /// - Parameter image: 측정할 이미지
    /// - Returns: 메모리 크기 (bytes)
    private static func estimateMemorySize(of image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = cgImage.bitsPerPixel / 8

        return width * height * bytesPerPixel
    }

    /// 바이트를 읽기 쉬운 형식으로 변환
    /// - Parameter bytes: 바이트 수
    /// - Returns: 포맷팅된 문자열 (예: "1.5 MB")
    private static func formatBytes(_ bytes: Int) -> String {
        let kb = 1024.0
        let mb = kb * 1024.0

        if bytes >= Int(mb) {
            return String(format: "%.2f MB", Double(bytes) / mb)
        } else if bytes >= Int(kb) {
            return String(format: "%.2f KB", Double(bytes) / kb)
        } else {
            return "\(bytes) bytes"
        }
    }
}
