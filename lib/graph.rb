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

  # Walks all vertices reachable from a given seed vertex or set of seed
  # vertices in either depth-first or breadth-first order. The method takes a
  # number of procs that trigger during certain phases of the walk:
  #
  # - previsit:  Called whenever a new vertex is first discovered as the
  #              adjacent vertex of the currently visited vertex. The proc will
  #              be called with the vertex v as the first parameter. previsit
  #              is also called before a seed vertex is visited; in the latter
  #              case the proc will receive a second paramter with the value
  #              true to indicate that the vertex v is a seed vertex.
  # - visit:     Called whenever a vertex is being visited; the proc will be
  #              called with the vertex v as the first and only paramter.
  # - postvisit: Called for vertex v once v as well as all vertices that were
  #              discovered as part of the exploration of v have been visited.
  def walk(order: :breadth_first, start: self.vertices,
           previsit: nil, visit: nil, postvisit: nil)
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
          next unless visited.add?(v)
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
    count = 0
    postorder = {}
    walk(order: :depth_first,
      postvisit: -> (v) { postorder[v] = count; count += 1 })
    edges.none? { |e| postorder[e.a] < postorder[e.b] }
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
