#!/usr/bin/env ruby -w
require './lib/graph'
data = STDIN
graph = Graph.load(data, true)
topo = data.readline.split.map(&:to_i)
idx = topo.each_with_index.reduce({}) { |h, (v, i)| h[v] = i; h }
correct = graph.edges.all? {|e| idx[e.a] < idx[e.b] }
puts correct ? "1" : "0"
