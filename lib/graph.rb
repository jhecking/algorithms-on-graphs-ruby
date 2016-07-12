#!/usr/bin/env ruby -w

require 'set'
require 'stringio'


class Graph
  attr_reader :vertices, :edges
  attr_reader :directed
  alias_method :directed?, :directed

  Infinity = Float::INFINITY
  Edge = Struct.new(:a, :b, :weight)

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
      vertices.each do |v|
        adj[v] = Set.new
      end
      edges.each do |e|
        adj[e.a] << e.b
        adj[e.b] << e.a unless directed?
      end
      adj
    end
  end

  def edges_from
    @edges_by_vertex ||= begin
      edges_by_vertex = {}
      vertices.each do |v|
        edges_by_vertex[v] = Set.new
      end
      edges.each do |e|
        edges_by_vertex[e.a] << e
        edges_by_vertex[e.b] << e unless directed?
      end
      edges_by_vertex
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

  def djikstra(s)
    known = Set.new
    dist = vertices.inject({}) { |h, v| h[v] = Infinity; h }
    prev = {}
    dist[s] = 0
    queue = MinHeap.new(vertices.map {|v| [v, dist[v]]})
    while (u = queue.pop) do
      next unless known.add?(u)
      edges_from[u].each do |edge|
        if relax_edge(edge, dist, prev)
          v = edge.b
          queue.insert(v, dist[v])
        end
      end
    end
    [dist, prev]
  end

  def bellman_ford(s)
    dist = vertices.inject({}) { |h, v| h[v] = Infinity; h }
    prev = {}
    dist[s] = 0
    relaxed = false
    (vertices.length - 1).times do
      relaxed = false
      edges.each do |edge|
        relaxed ||= relax_edge(edge, dist, prev)
      end
      break unless relaxed
    end

    if relaxed
      relaxed = Set.new
      edges.each do |edge|
        if relax_edge(edge, dist, prev)
          relaxed << edge
        end
      end
      relaxed = false if relaxed.empty?
    end

    [dist, prev, relaxed]
  end

  def shortest_paths(s)
    (dist, _, relaxed) = bellman_ford(s)
    return dist unless relaxed
    bfs(start: relaxed.map{|edge| edge.b},
        visit: -> (v) {dist[v] = -Infinity})
    return dist
  end

  def has_negative_cycle?
    explored = Set.new
    vertices.each do |s|
      next if explored.member?(s)
      (dist, _, relaxed) = bellman_ford(s)
      return true if relaxed
      explored += dist.reject{|_, d| d == Infinity}.map{|v, _| v}
    end
    return false
  end

  def to_dot
    dot = StringIO.new
    type = directed? ? "digraph" : "graph"
    dot.puts("#{type} {")
    vertices.each do |v|
      dot.puts("  #{v};")
    end
    sep = directed? ? '->' : '--'
    edges.each do |e|
      dot.write("  #{[e.a, e.b] * sep}")
      dot.write(" [label=\"#{e.weight}\"]") if e.weight
      dot.puts(?;)
    end
    dot.puts("}")
    dot.string
  end

  private

  def relax_edge(edge, dist, prev = nil)
    v, w = edge.a, edge.b
    if dist[w] > dist[v] + edge.weight
      dist[w] = dist[v] + edge.weight
      prev[w] = v if prev
      return true
    end
    return false
  end

  class MinHeap
    def initialize(enumerable)
      heapify(enumerable)
    end

    def empty?
      @data.empty?
    end

    def size
      @data.size
    end

    def insert(key, value)
      @data << [key, value]
      sift_up(@data.length - 1)
    end

    def pop
      return nil if empty?
      return @data.pop.first if size == 1

      retval, @data[0] = @data[0], @data.pop
      sift_down(0)
      return retval.first
    end

    private

    def heapify(enum)
      @data = enum.to_a
      (size / 2).downto(1).each do |idx|
        sift_down(idx)
      end
    end

    def sift_up(pos)
      while pos > 0
        parent = ((pos + 1) / 2) - 1
        if compare(parent, pos)
          swap(parent, pos)
          pos = parent
        else
          return
        end
      end
    end

    def sift_down(pos)
      loop do
        left = ((pos + 1) * 2) - 1
        right = left + 1
        next_child = left
        break if left >= size
        if right < size
          next_child = right unless compare(right, left)
        end
        break if compare(next_child, pos)
        swap(next_child, pos)
        pos = next_child
      end
    end

    def compare(pos1, pos2)
      @data[pos2].last < @data[pos1].last
    end

    def swap(pos1, pos2)
      @data[pos1], @data[pos2] = @data[pos2], @data[pos1]
    end
  end

end

profile = false
ARGV.each do |arg|
  case arg
  when '-p', '--prof' then profile = true
  end
end

if profile
  require 'ruby-prof'
  RubyProf.start
end

case File.basename($0, '.*')
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
when 'djikstra'
  graph = Graph.load(STDIN)
  (s, t) = STDIN.readline.split.map(&:to_i)
  (dist, _) = graph.djikstra(s)
  puts (d = dist[t]) == Graph::Infinity ? "-1" : d
when 'reachability'
  graph = Graph.load(STDIN)
  (s, t) = STDIN.readline.split.map(&:to_i)
  puts graph.reachable?(s, t) ? 1 : 0
when 'strongly_connected'
  puts Graph.load(STDIN, true).strongly_connected_components.length
when 'toposort'
  puts Graph.load(STDIN, true).toposort.join(' ')
when 'negative_cycle'
  puts Graph.load(STDIN, true).has_negative_cycle? ? "1" : "0"
when 'shortest_paths'
  graph = Graph.load(STDIN, true)
  s = STDIN.readline.to_i
  dist = graph.shortest_paths(s)
  puts dist.sort_by(&:first).map(&:last).map {|v|
    v == Graph::Infinity ? ?* :
      v == -Graph::Infinity ? ?- : v
  }
end

if profile
  profile = RubyProf.stop
  RubyProf::FlatPrinter.new(profile).print(STDOUT)
end
