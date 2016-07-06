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

  def walk(order: :breadth_first, start: self.vertices,
           previsit: nil, visit: nil, postvisit: nil,
           cycle: nil)
    visited = Set.new()
    pending = Pending.new(order == :breadth_first ? :queue : :stack)
    postorder = Pending.new(:stack)
    Array(start).each do |s|
      next unless visited.add?(s)
      previsit.call(s, true) if previsit
      pending.put(s)
      postorder.put(s) if postvisit
      while (u = pending.take) do
        visit.call(u) if visit
        self.adjacencies[u].each do |v|
          unless visited.add?(v)
            cycle.call(v) if cycle
            next
          end
          previsit.call(v, false) if previsit
          pending.put(v)
          postorder.put(v) if postvisit
        end
      end
      while (v = postorder.take) do
        postvisit.call(v)
      end
    end
  end

  def acyclic?
    walk(cycle: proc { return false })
    return true
  end

  def dag?
    directed? && acyclic?
  end

  def toposort
    topo = []
    walk(order: :depth_first,
         postvisit: -> (v) { topo.unshift(v) })
    topo
  end

  def shortest_path(s, t)
    curr = s
    prev = {}
    walk(order: :breadth_first, start: s,
        visit: -> (v) { curr = v },
        previsit: -> (v, seed) { prev[v] = curr unless seed })

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
    walk(order: :breadth_first, start: s,
      visit: -> (v) { current_dist = dist[v] },
      previsit: -> (v, seed) { dist[v] = current_dist + 1 unless seed })
    dist
  end

  def reachable?(s, t)
    walk(order: :depth_first, start: s,
      previsit: proc { |v| return true if v == t })
    return false
  end

  def connected_components
    components = Set.new
    curr = nil
    walk(order: :depth_first,
      previsit: -> (v, seed) { components << (curr = Set.new) if seed; curr << v })
    components
  end

  # simple list data structure that can switch between
  # queue and stack insert order, i.e. first-in/first-out
  # vs. last-in/first-out
  class Pending
    def initialize(mode)
      @list = []
      @mode = mode
      # insert position for new elements
      @pos = (mode == :queue) ? -1 : 0
    end

    def take
      @list.shift
    end

    def put(e)
      @list.insert(@pos, e)
    end

    def to_s
      "<#{@mode}: #{@list}>"
    end
  end

end
