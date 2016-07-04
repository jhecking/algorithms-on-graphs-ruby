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

  def reachable?(from, to)
    explore(from, previsit: Proc.new { |v| return true if v == to }) or false
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
