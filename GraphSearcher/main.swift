//
//  main.swift
//  GraphSearcher
//
//  Created by Сергей Зайцев on 19.04.2025.
//

import Foundation

// MARK: - Базовые структуры данных
struct Graph: CustomStringConvertible {
    var nodes: [Int: Node]
    var edges: [Edge]

    init() {
        self.nodes = [:]
        self.edges = []
    }

    var description: String {
        "Nodes: \(nodes.values.map { $0.id })\nEdges: \(edges.map { "\($0.from)->\($0.to)" })"
    }
}

struct Node: Hashable, Equatable {
    let id: Int
    var label: String
    var attributes: [String: AnyHashable]

    static func == (lhs: Node, rhs: Node) -> Bool {
        lhs.id == rhs.id && lhs.label == rhs.label
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Edge: Equatable {
    var from: Int
    var to: Int
    var label: String
}

// MARK: - Поисковый модуль
class SubgraphMatcher {
    private let hostGraph: Graph

    init(hostGraph: Graph) {
        self.hostGraph = hostGraph
    }

    func findIsomorphicSubgraphs(query: Graph) -> [[Int: Int]] {
        var results: [[Int: Int]] = []
        let candidates = filterCandidates(query: query)

        for candidate in candidates {
            var mapping = [Int: Int]()
            if dfsMatch(queryNode: query.nodes.values.first!,
                        hostNode: candidate,
                        query: query,
                        mapping: &mapping) {
                results.append(mapping)
            }
        }
        return results
    }

    private func filterCandidates(query: Graph) -> [Node] {
        guard let queryNode = query.nodes.values.first else { return [] }

        return hostGraph.nodes.values.filter { node in
            node.label == queryNode.label &&
            degree(of: node) >= query.edges.count
        }
    }

    private func degree(of node: Node) -> Int {
        hostGraph.edges.filter { $0.from == node.id || $0.to == node.id }.count
    }

    private func dfsMatch(queryNode: Node,
                          hostNode: Node,
                          query: Graph,
                          mapping: inout [Int: Int]) -> Bool {
        mapping[queryNode.id] = hostNode.id

        if mapping.count == query.nodes.count {
            return validateFullMapping(mapping, query: query)
        }

        let nextQueryNodes = getUnmappedNeighbors(query: query, mapping: mapping)

        for nextQuery in nextQueryNodes {
            let candidates = getHostCandidates(for: nextQuery,
                                              hostParent: hostNode,
                                              mapping: mapping)

            for candidate in candidates {
                if !mapping.values.contains(candidate.id) {
                    if dfsMatch(queryNode: nextQuery,
                               hostNode: candidate,
                               query: query,
                               mapping: &mapping) {
                        return true
                    }
                    mapping.removeValue(forKey: nextQuery.id)
                }
            }
        }
        return false
    }

    private func getUnmappedNeighbors(query: Graph, mapping: [Int: Int]) -> [Node] {
        let mappedIds = Set(mapping.keys)
        return query.nodes.values.filter { !mappedIds.contains($0.id) }
    }

    private func getHostCandidates(for queryNode: Node,
                                  hostParent: Node,
                                  mapping: [Int: Int]) -> [Node] {
        let adjacentEdges = hostGraph.edges.filter {
            $0.from == hostParent.id || $0.to == hostParent.id
        }

        let neighborIds = adjacentEdges.map { edge in
            edge.from == hostParent.id ? edge.to : edge.from
        }

        return neighborIds.compactMap { hostGraph.nodes[$0] }
                          .filter { $0.label == queryNode.label }
    }

    private func validateFullMapping(_ mapping: [Int: Int], query: Graph) -> Bool {
        for edge in query.edges {
            guard let hostFrom = mapping[edge.from],
                  let hostTo = mapping[edge.to],
                  hostGraph.edges.contains(where: {
                      ($0.from == hostFrom && $0.to == hostTo) ||
                      ($0.to == hostFrom && $0.from == hostTo)
                  }) else {
                return false
            }
        }
        return true
    }
}

// MARK: - Трансформационный модуль
class GraphTransformer {
    enum Millicommand {
        case addNode(id: Int, label: String)
        case removeEdge(from: Int, to: Int)
        case mergeNodes(source: Int, target: Int)
        case updateAttribute(node: Int, key: String, value: AnyHashable)
    }

    func apply(commands: [Millicommand], to graph: inout Graph) {
        for command in commands {
            switch command {
            case .addNode(let id, let label):
                graph.nodes[id] = Node(id: id, label: label, attributes: [:])

            case .removeEdge(let from, let to):
                graph.edges.removeAll { $0.from == from && $0.to == to }

            case .mergeNodes(let source, let target):
                guard let sourceNode = graph.nodes[source],
                      var targetNode = graph.nodes[target] else { continue }

                targetNode.attributes.merge(sourceNode.attributes) { $1 }
                graph.nodes[target] = targetNode
                graph.nodes.removeValue(forKey: source)

                graph.edges = graph.edges.map { edge in
                    var modified = edge
                    if modified.from == source { modified.from = target }
                    if modified.to == source { modified.to = target }
                    return modified
                }

            case .updateAttribute(let node, let key, let value):
                graph.nodes[node]?.attributes[key] = value
            }
        }
    }
}

// MARK: - Имитационное ядро
class SimulationEngine {
    private var matcher: SubgraphMatcher
    private var transformer: GraphTransformer
    private var graph: Graph

    init(initialGraph: Graph) {
        self.graph = initialGraph
        self.matcher = SubgraphMatcher(hostGraph: initialGraph)
        self.transformer = GraphTransformer()
    }

    func runSimulation(query: Graph, commands: [GraphTransformer.Millicommand]) -> Graph {
        let mappings = matcher.findIsomorphicSubgraphs(query: query)

        for mapping in mappings {
            var subgraph = extractSubgraph(mapping: mapping)
            transformer.apply(commands: commands, to: &subgraph)
            mergeSubgraph(subgraph, mapping: mapping)
        }

        return graph
    }

    private func extractSubgraph(mapping: [Int: Int]) -> Graph {
        var subgraph = Graph()
        for (_, hostId) in mapping {
            if let node = graph.nodes[hostId] {
                subgraph.nodes[hostId] = node
            }
        }
        subgraph.edges = graph.edges.filter { edge in
            mapping.values.contains(edge.from) && mapping.values.contains(edge.to)
        }
        return subgraph
    }

    private func mergeSubgraph(_ subgraph: Graph, mapping: [Int: Int]) {
        for (queryId, hostId) in mapping {
            if let node = subgraph.nodes[hostId] {
                graph.nodes[hostId] = node
            }
        }
        graph.edges += subgraph.edges
    }
}

// MARK: - Пример использования
let initialGraph: Graph = {
    var g = Graph()

    // Создание узлов
    for i in 1...5 {
        g.nodes[i] = Node(id: i, label: "A", attributes: [:])
    }

    // Создание рёбер
    g.edges = [
        Edge(from: 1, to: 2, label: "edge"),
        Edge(from: 2, to: 3, label: "edge"),
        Edge(from: 3, to: 4, label: "edge"),
        Edge(from: 4, to: 5, label: "edge")
    ]
    return g
}()

let queryGraph: Graph = {
    var g = Graph()
    g.nodes[10] = Node(id: 10, label: "A", attributes: [:])
    g.nodes[20] = Node(id: 20, label: "A", attributes: [:])
    g.nodes[30] = Node(id: 30, label: "A", attributes: [:])

    g.edges = [
        Edge(from: 10, to: 20, label: "edge"),
        Edge(from: 20, to: 30, label: "edge")
    ]
    return g
}()

let simulationEngine = SimulationEngine(initialGraph: initialGraph)
let commands: [GraphTransformer.Millicommand] = [
    .addNode(id: 100, label: "NewNode"),
    .mergeNodes(source: 3, target: 100),
    .updateAttribute(node: 100, key: "status", value: "merged")
]

let result = simulationEngine.runSimulation(query: queryGraph, commands: commands)

//queryGraph
print("Данные 1:\n\(initialGraph)")
print("Данные 1:\n\(queryGraph)")
print("Данные 1:\n\(queryGraph)")

//print("Результат 1:\n\(queryGraph)")
//print("Результат 2:\n\(simulationEngine)")
//print("Результат 3:\n\()")

print("Результат 4:\n\(result)")



