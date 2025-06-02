//
//  SimulationEngine.swift
//  GraphSearcher
//
//  Created by Сергей Зайцев on 08.05.2025.
//
// MARK: - Алгоритм поиска

import Algorithms
import Foundation
import CryptoKit

// MARK: - Алгоритм поиска
class SubgraphMatcher {
    private let host: Graph
    private let pattern: Graph
    private var hostLayers: [Graph.Layer]
    
    init(host: Graph, pattern: Graph) {
        self.host = host
        self.pattern = pattern
        self.hostLayers = host.structuralLayers(maxDepth: pattern.nodes.count)
    }
    
    func findIsomorphisms() async -> [[Int: Int]] {
        guard validateLayers() else { return [] }
        
        return await withTaskGroup(of: [Int: Int].self) { group in
            for patternNode in pattern.nodes.values {
                group.addTask { self.findMatches(root: patternNode) }
            }
            
            return await group.reduce(into: [[Int: Int]]()) { partialResult, element in
                partialResult.append(element)
            }
        }
    }
    
    private func validateLayers() -> Bool {
        let patternLayers = pattern.structuralLayers(maxDepth: pattern.nodes.count)
        return zip(hostLayers, patternLayers).allSatisfy {
            $0.depth == $1.depth && !$0.hashes.intersection($1.hashes).isEmpty
        }
    }
    
    private func findMatches(root: Node) -> [Int: Int] {
        var mapping = [Int: Int]()
        var used = Set<Int>()
        let candidates = host.nodes.values.filter {
            $0.label == root.label &&
            host.neighbors(of: $0.id).count >= pattern.neighbors(of: root.id).count
        }
        
        for candidate in candidates {
            if dfsMatch(patternNode: root, hostNode: candidate, mapping: &mapping, used: &used) {
                return mapping
            }
        }
        return [:]
    }
    
    private func dfsMatch(patternNode: Node, hostNode: Node,
                         mapping: inout [Int: Int], used: inout Set<Int>) -> Bool {
        mapping[patternNode.id] = hostNode.id
        used.insert(hostNode.id)
        
        guard mapping.count < pattern.nodes.count else {
            return validateFullMapping(mapping)
        }
        
        for nextPattern in getAdjacentNodes(patternNode: patternNode, mapping: mapping) {
            let candidates = getCandidates(for: nextPattern, hostParent: hostNode, used: used)
            
            for candidate in candidates {
                if dfsMatch(patternNode: nextPattern, hostNode: candidate,
                           mapping: &mapping, used: &used) {
                    return true
                }
            }
        }
        
        mapping.removeValue(forKey: patternNode.id)
        used.remove(hostNode.id)
        return false
    }
    
    private func validateFullMapping(_ mapping: [Int: Int]) -> Bool {
        pattern.edges.allSatisfy { edge in
            guard let from = mapping[edge.from], let to = mapping[edge.to] else { return false }
            return host.edges.contains { $0.from == from && $0.to == to }
        }
    }
}

// MARK: - Вспомогательные методы
extension SubgraphMatcher {
    private func getAdjacentNodes(patternNode: Node, mapping: [Int: Int]) -> [Node] {
        pattern.edges
            .filter { $0.from == patternNode.id || $0.to == patternNode.id }
            .flatMap { [$0.from, $0.to] }
            .filter { !mapping.keys.contains($0) }
            .compactMap { pattern.nodes[$0] }
    }
    
    private func getCandidates(for patternNode: Node,
                              hostParent: Node,
                              used: Set<Int>) -> [Node] {
        host.neighbors(of: hostParent.id)
            .filter { !used.contains($0) }
            .compactMap { host.nodes[$0] }
            .filter { $0.label == patternNode.label }
    }
}

// MARK: - Милликоманды и трансформации
enum MilliCommand {
    case addNode(id: Int, label: String, attributes: [String: String])
    case mergeNodes(source: Int, target: Int, conflictResolver: (inout [String: String]) -> Void)
}
