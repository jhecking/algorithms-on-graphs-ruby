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

  def dfs(start: self.vertices, previsit: nil, postvisit: nil)
    visited = Set.new()
    stack = []
    postorder = []
    Array(start).each do |s|
      next if visited.member?(s)
      stack.push(s)
      while (u = stack.pop) do
        if u == postorder.last
          postvisit.call(u)
          postorder.pop
        end
        next unless visited.add?(u)
        previsit.call(u) if previsit
        postorder.push(u) and stack.push(u) if postvisit
        stack += adjacencies[u].to_a
      end
    end
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

  def connected_components
    components = Set.new
    component = nil
    depth = 0
    dfs(previsit: -> (v) { components << (component = Set.new) if (depth += 1) == 1; component << v },
      postvisit: -> (_) { depth -= 1 })
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
