//
//  DoublyLinkedList.swift
//  CurtainCall
//
//  Created by 서준일 on 12/7/25.
//

import Foundation

// MARK: - CacheNode

/// 캐시 노드 (이중 연결 리스트)
final class CacheNode {
    // MARK: - Properties

    var prev: CacheNode?
    var next: CacheNode?
    let key: String
    var metadata: CacheMetadata

    // MARK: - Initialization

    init(key: String, metadata: CacheMetadata) {
        self.key = key
        self.metadata = metadata
    }
}

// MARK: - DoublyLinkedList

/// LRU+LFU 혼합 정책을 위한 이중 연결 리스트
final class DoublyLinkedList {
    // MARK: - Properties

    /// 더미 head 노드 (sentinel)
    private let head: CacheNode

    /// 더미 tail 노드 (sentinel)
    private let tail: CacheNode

    /// HashMap for O(1) access
    private var hashMap: [String: CacheNode] = [:]

    /// 현재 노드 개수
    private(set) var count: Int = 0

    // MARK: - Initialization

    init() {
        // Sentinel 노드 생성 (더미 메타데이터)
        let dummyMetadata = CacheMetadata(
            url: "",
            targetSize: .zero
        )

        self.head = CacheNode(key: "head", metadata: dummyMetadata)
        self.tail = CacheNode(key: "tail", metadata: dummyMetadata)

        // head와 tail 연결
        head.next = tail
        tail.prev = head
    }

    // MARK: - Public Methods

    /// 노드 삽입 (head 바로 다음에 삽입)
    /// - Parameters:
    ///   - key: 캐시 키
    ///   - metadata: 메타데이터
    /// - Returns: 생성된 노드
    @discardableResult
    func insert(key: String, metadata: CacheMetadata) -> CacheNode {
        // 이미 존재하면 제거 후 재삽입
        if let existingNode = hashMap[key] {
            removeNode(existingNode)
        }

        let newNode = CacheNode(key: key, metadata: metadata)

        // head 다음에 삽입
        addToHead(newNode)

        // HashMap에 추가
        hashMap[key] = newNode
        count += 1

        return newNode
    }

    /// 노드 접근 (head로 이동)
    /// - Parameter key: 캐시 키
    /// - Returns: 접근한 노드 또는 nil
    @discardableResult
    func access(key: String) -> CacheNode? {
        guard let node = hashMap[key] else { return nil }

        // 메타데이터 접근 기록
        node.metadata.recordAccess()

        // 노드를 head로 이동
        removeNode(node)
        addToHead(node)

        return node
    }

    /// 노드 제거
    /// - Parameter key: 삭제할 캐시 키
    /// - Returns: 삭제 성공 여부
    @discardableResult
    func remove(key: String) -> Bool {
        guard let node = hashMap[key] else { return false }

        removeNode(node)
        hashMap.removeValue(forKey: key)
        count -= 1

        return true
    }

    /// 노드 조회 (이동 없이)
    /// - Parameter key: 캐시 키
    /// - Returns: 노드 또는 nil
    func getNode(key: String) -> CacheNode? {
        return hashMap[key]
    }

    /// 메타데이터 업데이트
    /// - Parameters:
    ///   - key: 캐시 키
    ///   - metadata: 새로운 메타데이터
    func updateMetadata(key: String, metadata: CacheMetadata) {
        guard let node = hashMap[key] else { return }
        node.metadata = metadata
    }

    /// 가장 가치가 낮은 노드 제거 (LRU+LFU 점수 기반)
    /// - Returns: 제거된 노드의 키 또는 nil
    func removeLeastValuable() -> String? {
        guard count > 0 else { return nil }

        // 최대 접근 횟수 계산
        let maxAccessCount = hashMap.values.map { $0.metadata.accessCount }.max() ?? 1

        // 모든 노드의 점수 계산
        var lowestScore = Double.infinity
        var lowestNode: CacheNode?

        var currentNode = head.next
        while currentNode !== tail {
            guard let node = currentNode else { break }

            let score = node.metadata.calculateScore(maxAccessCount: maxAccessCount)

            if score < lowestScore {
                lowestScore = score
                lowestNode = node
            }

            currentNode = node.next
        }

        // 가장 낮은 점수의 노드 제거
        if let nodeToRemove = lowestNode {
            let key = nodeToRemove.key
            remove(key: key)
            return key
        }

        return nil
    }

    /// 특정 크기만큼 노드 제거 (점수 낮은 순)
    /// - Parameter targetSize: 목표 크기 (bytes)
    /// - Returns: 제거된 키 배열
    func removeUntilSize(targetSize: Int) -> [String] {
        var removedKeys: [String] = []
        var currentSize = getTotalSize()

        while currentSize > targetSize, count > 0 {
            if let removedKey = removeLeastValuable() {
                removedKeys.append(removedKey)

                // 크기 재계산
                currentSize = getTotalSize()
            } else {
                break
            }
        }

        return removedKeys
    }

    /// 전체 크기 계산
    /// - Returns: 총 파일 크기 (bytes)
    func getTotalSize() -> Int {
        return hashMap.values.reduce(0) { $0 + $1.metadata.fileSize }
    }

    /// 전체 노드 제거
    func removeAll() {
        head.next = tail
        tail.prev = head
        hashMap.removeAll()
        count = 0
    }

    /// 모든 키 반환
    /// - Returns: 키 배열
    func getAllKeys() -> [String] {
        return Array(hashMap.keys)
    }

    /// 모든 메타데이터 반환
    /// - Returns: [키: 메타데이터] 딕셔너리
    func getAllMetadata() -> [String: CacheMetadata] {
        var result: [String: CacheMetadata] = [:]
        for (key, node) in hashMap {
            result[key] = node.metadata
        }
        return result
    }

    // MARK: - Private Methods

    /// 노드를 head 다음에 추가
    /// - Parameter node: 추가할 노드
    private func addToHead(_ node: CacheNode) {
        node.next = head.next
        node.prev = head

        head.next?.prev = node
        head.next = node
    }

    /// 노드를 리스트에서 제거 (메모리에서 삭제하지 않음)
    /// - Parameter node: 제거할 노드
    private func removeNode(_ node: CacheNode) {
        node.prev?.next = node.next
        node.next?.prev = node.prev
    }
}

// MARK: - Debug

extension DoublyLinkedList {
    /// 디버그용 리스트 출력
    func printList() {
        var current = head.next
        var keys: [String] = []

        while current !== tail {
            guard let node = current else { break }
            keys.append(node.key)
            current = node.next
        }

    }

    /// 통계 출력
    func printStatistics() {
        // Statistics logging removed
    }
}
