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
end
