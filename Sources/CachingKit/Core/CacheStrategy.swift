//
//  CacheStrategy.swift
//  CurtainCall
//
//  Created by 서준일 on 12/10/25.
//

import Foundation

/// 캐싱 전략을 정의하는 enum
public enum CacheStrategy {
    /// 메모리 캐시만 사용 (단기 데이터)
    case memoryOnly

    /// 디스크 캐시만 사용 (자주 안 바뀌는 데이터)
    case diskOnly

    /// 메모리 + 디스크 모두 사용 (기본값)
    case both
}
