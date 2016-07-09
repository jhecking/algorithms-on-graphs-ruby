#!/usr/bin/env ruby -w

require 'set'
require 'stringio'

Edge = Struct.new(:a, :b, :weight)

class Graph
  attr_reader :vertices, :edges
  attr_reader :directed
  alias_method :directed?, :directed

  def self.load(stream, directed = false)
    (v, e) = stream.readline.split.map(&:to_i)
    vertices = Set.new(1..v)
    edges = stream.take(e).map {|l| Edge.new(*l.split.map(&:to_i))}
    self.new(vertices, edges, directed)
  end

  def initialize(vertices, edges, directed = false)
    @edges = edges
    @vertices = vertices
    @directed = directed
  end

  def adjacencies
    @adj ||= begin
      adj = {}
      self.vertices.each do |v|
        adj[v] = Set.new
      end
      self.edges.each do |e|
        adj[e.a] << e.b
        adj[e.b] << e.a unless self.directed?
      end
      adj
    end
  end

  def reverse
    rev_edges = self.edges.map {|e| Edge.new(e.b, e.a, e.weight) }
    Graph.new(vertices.clone, rev_edges, directed)
  end

  def bfs(start: self.vertices, previsit: nil, visit: nil)
    visited = Set.new()
    queue = []
    Array(start).each do |s|
      next unless visited.add?(s)
      queue.push(s)
      while (u = queue.shift) do
        visit.call(u) if visit
        adjacencies[u].each do |v|
          next unless visited.add?(v)
          previsit.call(v) if previsit
          queue.push(v)
        end
      end
    end
  end

  ExitNode = Struct.new(:vertex)

  def dfs(start: self.vertices, previsit: nil, postvisit: nil)
    visited = Set.new()
    stack = []
    Array(start).each do |s|
      next if visited.member?(s)
      stack.push(s)
      while (u = stack.pop) do
        postvisit.call(u.vertex) and next if u.is_a? ExitNode
        next unless visited.add?(u)
        previsit.call(u) if previsit
        stack.push(ExitNode.new(u)) if postvisit
        stack += adjacencies[u].to_a
      end
    end
  end

  def dfs_post_order
    postorder = []
    dfs(postvisit: -> (v) { postorder << v })
    postorder
  end

  def acyclic?
    count = 0
    postorder = {}
    dfs(postvisit: -> (v) { postorder[v] = (count += 1) })
    edges.none? { |e| postorder[e.a] < postorder[e.b] }
  end

  def dag?
    directed? && acyclic?
  end

  def toposort
    topo = []
    dfs(postvisit: -> (v) { topo.unshift(v) })
    topo
  end

  def shortest_path(s, t)
    prev = {}
    current = s
    bfs(start: s,
      previsit: -> (v) { prev[v] = current },
      visit: -> (v) { current = v })

    # return early if t is not reachable from s
    return nil unless prev[t]

    path = []
    while t != s do
      path.unshift(t)
      t = prev[t]
    end
    path
  end

  def distances_from(s)
    dist = {}
    vertices.each do |v|
      dist[v] = -1
    end
    current = dist[s] = 0
    bfs(start: s,
      previsit: -> (v) { dist[v] = current + 1 },
      visit: -> (v) { current = dist[v] })
    dist
  end

  def reachable?(s, t)
    dfs(start: s, previsit: proc { |v| return true if v == t })
    return false
  end

  def connected_components(strong = false)
    seed_order = strong ? reverse.dfs_post_order.reverse : vertices
    components = []
    component = nil
    depth = 0
    dfs(start: seed_order,
      previsit: -> (v) { components << (component = Set.new) if depth == 0; depth += 1; component << v },
      postvisit: -> (_) { depth -= 1 })
    components
  end

  def strongly_connected_components
    connected_components(true)
  end

  def bipartite?
    groups = Hash.new(0)
    current = 0
    bfs(visit: -> (v) { current = groups[v] }, previsit: -> (v) { groups[v] = current.next % 2 })
    edges.all? { |e| groups[e.a] != groups[e.b] }
  end

  def to_dot
    dot = StringIO.new
    dot.puts("#{directed? ? 'digraph' : 'graph'} name {")
    vertices.each do |v|
      dot.puts("  #{v};")
    end
    edges.each do |e|
      dot.puts("  #{e.a} #{directed? ? '->' : '--'} #{e.b};")
    end
    dot.puts("}")
    dot.string
  end

end


case (command = File.basename($0, '.*'))
when 'acyclicity'
  puts Graph.load(STDIN, true).acyclic? ? "0" : "1"
when 'bfs'
  graph = Graph.load(STDIN)
  (s, t) = STDIN.readline.split.map(&:to_i)
  path = graph.shortest_path(s, t)
  puts path ? path.length : -1
when 'bipartite'
  puts Graph.load(STDIN).bipartite? ? "1" : "0"
when 'connected_components'
  puts Graph.load(STDIN, false).connected_components.length
when 'reachability'
  graph = Graph.load(STDIN)
  (s, t) = STDIN.readline.split.map(&:to_i)
  puts graph.reachable?(s, t) ? 1 : 0
when 'strongly_connected'
  puts Graph.load(STDIN, true).strongly_connected_components.length
when 'toposort'
  puts Graph.load(STDIN, true).toposort.join(' ')
else
  warn "Unknown command: #{command}"
end
