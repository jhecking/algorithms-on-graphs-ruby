require './lib/graph'

describe Graph do

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
      expect(subject.connected_components).to eql([[1, 2, 3].to_set, [4].to_set].to_set)
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
      subject = Graph.load(data, true)
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
end
