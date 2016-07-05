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

  def bfs(s, preprocess: nil, discovered: nil)
    visited = Set.new([s])
    queue = [s]
    while (u = queue.shift) do
      preprocess.call(u) if preprocess
      self.adjacencies[u].each do |v|
        next unless visited.add?(v)
        queue << v
        discovered.call(v) if discovered
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
    bfs(s, 
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
    dist = {s => 0}
    self.vertices.each do |v|
      dist[v] ||= -1
    end
    current_dist = 0
    bfs(s,
        preprocess: -> (v) { current_dist = dist[v] },
        discovered: -> (v) { dist[v] = current_dist + 1 })
    dist
  end

  def reachable?(s, t)
    explore(s, previsit: Proc.new { |v| return true if v == t }) or false
  end

  def connected_components
    visited = Set.new
    components = Set.new
    self.vertices.each do |v|
      next if visited.member?(v)
      component = Set.new
      explore(v, visited: visited, previsit: -> (w) { component << w })
      components << component
    end
    components
  end

end
