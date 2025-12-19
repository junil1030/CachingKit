//
//  String+Hash.swift
//  CurtainCall
//
//  Created by 서준일 on 12/7/25.
//

import Foundation
import CryptoKit

extension String {
    /// SHA256 해시 생성
    var sha256: String {
        guard let data = self.data(using: .utf8) else { return self }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// MD5 해시 생성 (더 짧은 키가 필요한 경우)
    var md5: String {
        guard let data = self.data(using: .utf8) else { return self }
        let hash = Insecure.MD5.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
