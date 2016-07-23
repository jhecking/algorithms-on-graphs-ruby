#!/usr/bin/env ruby -w
require './lib/graph'
data = STDIN
graph = Graph.load(data, true)
topo = data.readline.split.map(&:to_i)
idx = topo.each_with_index.reduce({}) { |h, (v, i)| h[v] = i; h }
edges = graph.edges.select {|e| idx[e.a] >= idx[e.b] }
puts edges.empty? ? "1" : "0"
puts edges.map { |e| [e.a, e.b] * " -> " } unless edges.empty?
