//
//  GraphTransformer.swift
//  GraphSearcher
//
//  Created by Сергей Зайцев on 08.05.2025.
//

import Foundation

class GraphTransformer {
    private(set) var graph: Graph
    
    init(graph: Graph) {
        self.graph = graph
    }
    
    func apply(_ command: MilliCommand) {
        switch command {
        case .addNode(let id, let label, let attributes):
            graph.nodes[id] = Node(id: id, label: label, attributes: attributes)
            
        case .mergeNodes(let source, let target, let resolver):
            guard let sourceNode = graph.nodes[source],
                  var targetNode = graph.nodes[target] else { return }
            
            resolver(&targetNode.attributes)
            graph.nodes[target] = targetNode
            graph.nodes.removeValue(forKey: source)
            
            graph.edges = Set(graph.edges.map { edge in
                if edge.from == source {
                    return Edge(from: target, to: edge.to, label: edge.label)
                } else if edge.to == source {
                    return Edge(from: edge.from, to: target, label: edge.label)
                }
                return edge
            })
        }
    }
}
