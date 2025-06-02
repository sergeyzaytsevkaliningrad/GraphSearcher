//
//  BaseGraph.swift
//  GraphSearcher
//
//  Created by Сергей Зайцев on 08.05.2025.
//
//
//
import Foundation
import CryptoKit

// MARK: - Базовые структуры данных
struct Node: Hashable {
    let id: Int
    var label: String
    var attributes: [String: String]
}

struct Edge: Hashable {
    let from: Int
    let to: Int
    var label: String
}

struct Graph {
    var nodes: [Int: Node]
    var edges: Set<Edge>
    
    func neighbors(of nodeId: Int) -> Set<Int> {
        edges.reduce(into: Set<Int>()) { result, edge in
            if edge.from == nodeId { result.insert(edge.to) }
            if edge.to == nodeId { result.insert(edge.from) }
        }
    }
}

// MARK: - Построение структурных слоек
extension Graph {
    struct Layer {
        let depth: Int
        var hashes: Set<String>
    }
    
    func structuralLayers(maxDepth: Int) -> [Layer] {
        (1...maxDepth).map { depth in
            var hashes = Set<String>()
            let combinations = nodes.keys.combinations(ofCount: depth)
            
            for combo in combinations where isConnected(Array(combo)) {
                let nodeLabels = combo.sorted().map { nodes[$0]!.label }
                let edgeLabels = edges.filter {
                    combo.contains($0.from) && combo.contains($0.to)
                }.map { $0.label }.sorted()
                
                let hash = SHA256.hash(data: Data((nodeLabels + edgeLabels).joined().utf8))
                    .description
                hashes.insert(hash)
            }
            return Layer(depth: depth, hashes: hashes)
        }
    }
    
    private func isConnected(_ nodeIds: [Int]) -> Bool {
        guard !nodeIds.isEmpty else { return false }
        var visited = Set<Int>()
        var queue = [nodeIds[0]]
        
        while !queue.isEmpty {
            let current = queue.removeFirst()
            visited.insert(current)
            
            for neighbor in neighbors(of: current) where nodeIds.contains(neighbor) {
                if !visited.contains(neighbor) { queue.append(neighbor) }
            }
        }
        return visited.count == nodeIds.count
    }
}
