require './lib/graph'

describe Graph do

  describe ".load_connected_coords" do
    it "converts the coordinate pairs into a fully connected graph" do
      data = StringIO.new <<EOT
4
0 0
0 1
1 0
1 1
EOT
      subject = described_class.load_connected_coords(data)
      expect(subject.vertices).to contain_exactly(1, 2, 3, 4)
      expect(subject.edges.map(&:weight)).to contain_exactly(1, 1, 1, 1, Math.sqrt(2), Math.sqrt(2))
    end
  end

  describe '#reachable?' do
    it 'returns true if v2 is reachable from v1' do
      subject = described_class.load StringIO.new <<EOT
4 4
1 2
2 3
3 4
4 1
EOT
      expect(subject.reachable?(1, 3)).to be(true)
    end

    it 'returns false if v2 is not reachable from v1' do
      subject = described_class.load StringIO.new <<EOT
4 2
1 2
3 2
EOT
      expect(subject.reachable?(1, 4)).to be(false)
    end
  end

  describe '#connected_components' do
    it 'returns two connected components' do
      subject = described_class.load StringIO.new <<EOT
4 2
1 2
3 2
EOT
      expect(subject.connected_components).to eql([Set.new([1, 2, 3]), Set.new([4])])
    end
  end

  describe '#strongly_connected_components' do
    it 'returns a single strongly connected compoent' do
      data = StringIO.new <<EOT
4 4
1 2
4 1
2 3
3 1
EOT
      subject = described_class.load(data, true)
      components = subject.connected_components(true)
      expect(components).to eql([Set.new([1, 3, 2]), Set.new([4])])
    end
  end

  describe '#acyclic?' do
    context 'directed graphs' do
      it 'returns true if the graph does not have any cycles' do
        data = StringIO.new <<EOT
5 7
1 2
2 3
1 3
3 4
1 4
2 5
3 5
EOT
        subject = described_class.load(data, true)
        expect(subject.acyclic?).to be(true)
      end

      it 'returns false if the graph has at least one cycle' do
        data = StringIO.new <<EOT
4 4
1 2
4 1
2 3
3 1
EOT
        subject = described_class.load(data, true)
        expect(subject.acyclic?).to be(false)
      end

      it 'ignores "false" circles in directed graphs' do
        data = StringIO.new <<EOT
3 3
1 2
1 3
2 3
EOT
        subject = described_class.load(data, true)
        expect(subject.acyclic?).to be(true)
      end
    end

    context 'undirected graphs' do
      it 'returns true if the graph does not have any cycles' do
        subject = described_class.load StringIO.new <<EOT
5 4
1 2
1 3
1 4
3 5
EOT
        expect(subject.acyclic?).to be(true)
      end

      it 'returns false if the graph has at least one cycle' do
        subject = described_class.load StringIO.new <<EOT
4 4
1 2
4 1
2 3
3 1
EOT
        expect(subject.acyclic?).to be(false)
      end
    end
  end

  describe '#toposort' do
    it 'returns the vertices in topological order' do
      data = StringIO.new <<EOT
4 3
1 2
4 1
3 1
EOT
      subject = described_class.load(data, true)
      expect(subject.toposort).to eql([4, 3, 1, 2])
    end
  end

  describe '#shortest_path' do
    it 'returns the shortest path from s to t' do
      subject = described_class.load StringIO.new <<EOT
4 4
1 2
4 1
2 3
3 1
EOT
      expect(subject.shortest_path(2, 4)).to eql([1, 4])
    end

    it 'returns empty path for s -> s' do
      subject = described_class.load StringIO.new <<EOT
4 4
1 2
4 1
2 3
3 1
EOT
      expect(subject.shortest_path(2, 2)).to be(nil)
    end

    it 'returns nil if t is not reachable from s' do
      subject = described_class.load StringIO.new <<EOT
5 4
5 2
1 3
3 4
1 4
EOT
      expect(subject.shortest_path(3, 2)).to be(nil)
    end
  end

  describe '#distances_from' do
    it 'returns the distances from s' do
      subject = described_class.load StringIO.new <<EOT
4 4
1 2
4 1
2 3
3 1
EOT
      expect(subject.distances_from(2)).to eql({1 => 1, 2 => 0, 3 => 1, 4 => 2})
    end

    it 'returns -1 for nodes that are unreachable' do
      subject = described_class.load StringIO.new <<EOT
5 4
5 2
1 3
3 4
1 4
EOT
      expect(subject.distances_from(3)).to eql({1 => 1, 2 => -1, 3 => 0, 4 => 1, 5 => -1})
    end
  end

  describe '#bipartite?' do
    it 'returns true if all edges span vertices from two different groups' do
      subject = described_class.load StringIO.new <<EOT
5 4
5 2
4 2
3 4
1 4
EOT
      expect(subject.bipartite?).to eq(true)
    end

    it 'returns false if some edges span vertices of the same group group' do
      subject = described_class.load StringIO.new <<EOT
4 4
1 2
4 1
2 3
3 1
EOT
      expect(subject.bipartite?).to eq(false)
    end
  end

  describe '#djikstra' do
    it 'finds the shortest path from vertex s to each other node in a weighted, directed graph' do
      data = StringIO.new <<EOT
4 4
1 2 1
4 1 2
2 3 2
1 3 5
EOT
      subject = described_class.load(data, true)
      (dist, prev) = subject.djikstra(1)
      expect(dist).to eq({ 1 => 0, 2 => 1, 3 => 3, 4 => Graph::Infinity })
      expect(prev).to eq({ 2 => 1, 3 => 2 })
    end
  end

  describe '#negative_cycle' do
    it 'returns true if the graph has a negative weight cycle' do
      data = StringIO.new <<EOT
4 4
1 2 -5
4 1 2
2 3 2
3 1 1
EOT
      subject = described_class.load(data, true)
      expect(subject.has_negative_cycle?).to be(true)
    end

    it 'returns false if the graph has a cycle but the weight is not negative' do
      data = StringIO.new <<EOT
4 4
1 2 -5
4 1 2
2 3 4
3 1 1
EOT
      subject = described_class.load(data, true)
      expect(subject.has_negative_cycle?).to be(false)
    end

    it 'returns false if the graph has no cycles' do
      data = StringIO.new <<EOT
4 4
1 2 -5
4 1 2
3 2 2
3 1 1
EOT
      subject = described_class.load(data, true)
      expect(subject.has_negative_cycle?).to be(false)
    end
  end

  describe "#prim" do
    it "returns a minimum spanning tree" do
      data = StringIO.new <<EOT
5
0 0
0 2
1 1
3 0
3 2
EOT
      subject = described_class.load_connected_coords(data)
      mst = subject.prim
      expect(mst.size).to eq(4)
      vertices = mst.reduce(Set.new){|v, e| v += Set.new([e.a, e.b])}
      expect(vertices).to contain_exactly(1, 2, 3, 4, 5)
      weight = mst.reduce(0){|sum, e| sum += e.weight}
      expect(weight).to be_within(0.0001).of(7.0645)
    end
  end

end
