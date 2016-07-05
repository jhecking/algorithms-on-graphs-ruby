require 'set'

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

  def explore(v, visited: Set.new, previsit: nil, postvisit: nil)
    visited << v
    previsit.call(v) if previsit
    self.adjacencies[v].each do |w|
      next if visited.member?(w)
      explore(w, visited: visited, previsit: previsit, postvisit: postvisit)
    end
    postvisit.call(v) if postvisit
  end

  def search(order: :bfs, start: self.vertices, seed: nil, preprocess: nil, discovered: nil)
    visited = Set.new()
    Array(start).each do |s|
      next unless visited.add?(s)
      seed.call(s) if seed
      queue = [s]
      while (u = queue.shift) do
        preprocess.call(u) if preprocess
        self.adjacencies[u].each do |v|
          next unless visited.add?(v)
          queue.insert(order == :bfs ? -1 : 0, v)
          discovered.call(v) if discovered
        end
      end
    end
  end

  def toposort
    visited = Set.new
    topo = []
    self.vertices.each do |v|
      next if visited.member?(v)
      explore(v, visited: visited, postvisit: -> (w) { topo.unshift(w) })
    end
    topo
  end

  def shortest_path(s, t)
    curr = s
    prev = {}
    search(order: :bfs, start: s,
        preprocess: -> (v) { curr = v },
        discovered: -> (v) { prev[v] = curr })

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
    self.vertices.each do |v|
      dist[v] ||= -1
    end
    dist[s] = 0
    current_dist = 0
    search(order: :bfs, start: s,
      preprocess: -> (v) { current_dist = dist[v] },
      discovered: -> (v) { dist[v] = current_dist + 1 })
    dist
  end

  def reachable?(s, t)
    search(order: :dfs, start: s,
      discovered: Proc.new { |v| return true if v == t })
    return false
  end

  def connected_components
    components = Set.new
    curr = nil
    search(order: :dfs,
      seed: -> (v) { curr = Set.new([v]); components << curr },
      discovered: -> (v) { curr << v })
    components
  end

end
