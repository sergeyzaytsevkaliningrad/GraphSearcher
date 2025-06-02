//
//  main.swift
//  GraphSearcher
//
//  Created by Сергей Зайцев on 19.04.2025.
//

import Foundation
import CryptoKit

// Пример использования
let hostGraph = Graph(
    nodes: [
        1: Node(id: 1, label: "A", attributes: [:]),
        2: Node(id: 2, label: "B", attributes: [:]),
        3: Node(id: 3, label: "A", attributes: [:])
    ],
    edges: [
        Edge(from: 1, to: 2, label: "X"),
        Edge(from: 2, to: 3, label: "Y")
    ]
)

let patternGraph = Graph(
    nodes: [
        10: Node(id: 10, label: "A", attributes: [:]),
        20: Node(id: 20, label: "B", attributes: [:])
    ],
    edges: [
        Edge(from: 10, to: 20, label: "X")
    ]
)

Task {
    let matcher = SubgraphMatcher(host: hostGraph, pattern: patternGraph)
    let results = await matcher.findIsomorphisms()
    
    print("Найдено совпадений: \(results.count)")
    results.forEach { mapping in
        let pairs = mapping.map { "\($0.key)→\($0.value)" }.joined(separator: ", ")
        print("Соответствие: { \(pairs) }")
        
        let transformer = GraphTransformer(graph: hostGraph)
        transformer.apply(.mergeNodes(source: mapping[10]!, target: mapping[20]!) { $0["merged"] = "true" })
        print("Объединённые узлы: \(transformer.graph.nodes)")
    }
}

// MARK: - Примеры использования с подробным выводом

func printMapping(_ mapping: [Int: Int], host: Graph, pattern: Graph) {
    print("\n▻ Найдено соответствие:")
    for (patternId, hostId) in mapping.sorted(by: { $0.key < $1.key }) {
        guard let patternNode = pattern.nodes[patternId],
              let hostNode = host.nodes[hostId] else { continue }
        
        print("Узел шаблона \(patternNode.label)(\(patternId)) → \(hostNode.label)(\(hostId))")
    }
    
    // Проверка рёбер
    var isValid = true
    for edge in pattern.edges {
        guard let hostFrom = mapping[edge.from],
              let hostTo = mapping[edge.to],
              host.edges.contains(Edge(from: hostFrom, to: hostTo, label: edge.label)) else {
            isValid = false
            break
        }
    }
    print("Валидация рёбер: \(isValid ? "✅" : "❌")")
}

// Пример 1: Простой случай (3 узла в цепочке)
func example1() {
    print("\n\n=== Пример 1: Поиск цепочки A-B-A ===")
    
    let hostGraph = Graph(
        nodes: [
            1: Node(id: 1, label: "A", attributes: [:]),
            2: Node(id: 2, label: "B", attributes: [:]),
            3: Node(id: 3, label: "A", attributes: [:])
        ],
        edges: [
            Edge(from: 1, to: 2, label: "X"),
            Edge(from: 2, to: 3, label: "Y")
        ]
    )
    
    let patternGraph = Graph(
        nodes: [
            10: Node(id: 10, label: "A", attributes: [:]),
            20: Node(id: 20, label: "B", attributes: [:]),
            30: Node(id: 30, label: "A", attributes: [:])
        ],
        edges: [
            Edge(from: 10, to: 20, label: "X"),
            Edge(from: 20, to: 30, label: "Y")
        ]
    )
    
    let finder = SubgraphMatcher(host: hostGraph, pattern: patternGraph)
    Task {
        let results = await finder.findIsomorphisms()
        print("\nРезультаты для примера 1:")
        print("Всего совпадений: \(results.count)")
        results.forEach { printMapping($0, host: hostGraph, pattern: patternGraph) }
    }
}

// Пример 2: Граф без совпадений
func example2() {
    print("\n\n=== Пример 2: Поиск несуществующего паттерна ===")
    
    let hostGraph = Graph(
        nodes: [
            1: Node(id: 1, label: "C", attributes: [:]),
            2: Node(id: 2, label: "D", attributes: [:])
        ],
        edges: [
            Edge(from: 1, to: 2, label: "Z")
        ]
    )
    
    let patternGraph = Graph(
        nodes: [
            10: Node(id: 10, label: "A", attributes: [:]),
            20: Node(id: 20, label: "B", attributes: [:])
        ],
        edges: [
            Edge(from: 10, to: 20, label: "X")
        ]
    )
    
    let finder = SubgraphMatcher(host: hostGraph, pattern: patternGraph)
    Task {
        let results = await finder.findIsomorphisms()
        print("\nРезультаты для примера 2:")
        print("Совпадений не найдено: \(results.isEmpty ? "✅" : "❌")")
    }
}

func example3() {
    print("\n=== Пример 3: Масштабируемость (кольцо из 5 узлов) ===")
    
    // Исправлено: инициализация с пустыми коллекциями
    var hostGraph = Graph(nodes: [:], edges: [])
    for i in 1...5 {
        let label = i % 2 == 0 ? "B" : "A"
        hostGraph.nodes[i] = Node(id: i, label: label, attributes: [:])
    }
    hostGraph.edges = [
        Edge(from: 1, to: 2, label: "X"),
        Edge(from: 2, to: 3, label: "Y"),
        Edge(from: 3, to: 4, label: "X"),
        Edge(from: 4, to: 5, label: "Y"),
        Edge(from: 5, to: 1, label: "Z")
    ]
    
    let patternGraph = Graph(
        nodes: [
            10: Node(id: 10, label: "A", attributes: [:]),
            20: Node(id: 20, label: "B", attributes: [:]),
            30: Node(id: 30, label: "A", attributes: [:])
        ],
        edges: [
            Edge(from: 10, to: 20, label: "X"),
            Edge(from: 20, to: 30, label: "Y")
        ]
    )
    
    let finder = SubgraphMatcher(host: hostGraph, pattern: patternGraph)
    Task {
        let startTime = Date()
        let results = await finder.findIsomorphisms()
        let duration = String(format: "%.4f", Date().timeIntervalSince(startTime))
        
        print("\nРезультаты для графа из 5 узлов:")
        print("▻ Время выполнения: \(duration) сек")
        print("▻ Найдено совпадений: \(results.count)")
        
        results.prefix(3).enumerated().forEach { index, mapping in
            print("\nСовпадение \(index+1):")
            mapping.sorted(by: { $0.key < $1.key }).forEach { (patternId, hostId) in
                let patternNode = patternGraph.nodes[patternId]!
                let hostNode = hostGraph.nodes[hostId]!
                print("  \(patternNode.label)\(patternId) → \(hostNode.label)\(hostId)")
            }
            let isValid = patternGraph.edges.allSatisfy { edge in
                guard let from = mapping[edge.from],
                      let to = mapping[edge.to],
                      hostGraph.edges.contains(Edge(from: from, to: to, label: edge.label)) else {
                    return false
                }
                return true
            }
            print("Валидация рёбер: \(isValid ? "✅" : "❌")")
        }
        
        if results.count > 3 {
            print("... и ещё \(results.count - 3) совпадений")
        }
        
        // Пример трансформации
        if let firstMatch = results.first {
            var transformer = GraphTransformer(graph: hostGraph)
            transformer.apply(.mergeNodes(source: firstMatch[20]!, target: firstMatch[10]!) {
                $0["merged"] = "\(Date())"
            })
            print("\nПосле трансформации:")
            print("▻ Узлы: \(transformer.graph.nodes.keys.sorted())")
            print("▻ Рёбра: \(transformer.graph.edges.map { "\($0.from)-\($0.to)" })")
        }
    }
}

func example4() {
    print("\n=== Пример 3: Масштабируемость (кольцо из 5 узлов) ===")
    
    // Исправлено: инициализация с пустыми коллекциями
    var hostGraph = Graph(nodes: [:], edges: [])
    for i in 1...15 {
        let label = i % 2 == 0 ? "B" : "A"
        hostGraph.nodes[i] = Node(id: i, label: label, attributes: [:])
    }
    hostGraph.edges = [
        Edge(from: 1, to: 2, label: "X"),
        Edge(from: 2, to: 3, label: "Y"),
        Edge(from: 3, to: 4, label: "X"),
        Edge(from: 4, to: 5, label: "Y"),
        Edge(from: 5, to: 1, label: "Z")
    ]
    
    let patternGraph = Graph(
        nodes: [
            10: Node(id: 10, label: "A", attributes: [:]),
            20: Node(id: 20, label: "B", attributes: [:]),
            30: Node(id: 30, label: "A", attributes: [:])
        ],
        edges: [
            Edge(from: 10, to: 20, label: "X"),
            Edge(from: 20, to: 30, label: "Y")
        ]
    )
    
    let finder = SubgraphMatcher(host: hostGraph, pattern: patternGraph)
    Task {
        let startTime = Date()
        let results = await finder.findIsomorphisms()
        let duration = String(format: "%.4f", Date().timeIntervalSince(startTime))
        
        print("\nРезультаты для графа из 5 узлов:")
        print("▻ Время выполнения: \(duration) сек")
        print("▻ Найдено совпадений: \(results.count)")
        
        results.prefix(3).enumerated().forEach { index, mapping in
            print("\nСовпадение \(index+1):")
            mapping.sorted(by: { $0.key < $1.key }).forEach { (patternId, hostId) in
                let patternNode = patternGraph.nodes[patternId]!
                let hostNode = hostGraph.nodes[hostId]!
                print("  \(patternNode.label)\(patternId) → \(hostNode.label)\(hostId)")
            }
            let isValid = patternGraph.edges.allSatisfy { edge in
                guard let from = mapping[edge.from],
                      let to = mapping[edge.to],
                      hostGraph.edges.contains(Edge(from: from, to: to, label: edge.label)) else {
                    return false
                }
                return true
            }
            print("Валидация рёбер: \(isValid ? "✅" : "❌")")
        }
        
        if results.count > 3 {
            print("... и ещё \(results.count - 3) совпадений")
        }
        
        // Пример трансформации
        if let firstMatch = results.first {
            var transformer = GraphTransformer(graph: hostGraph)
            transformer.apply(.mergeNodes(source: firstMatch[20]!, target: firstMatch[10]!) {
                $0["merged"] = "\(Date())"
            })
            print("\nПосле трансформации:")
            print("▻ Узлы: \(transformer.graph.nodes.keys.sorted())")
            print("▻ Рёбра: \(transformer.graph.edges.map { "\($0.from)-\($0.to)" })")
        }
    }
}

// Запуск примеров
example1()
example2()
example3()
example4()
