require './lib/graph'

describe Graph do

  describe ".new" do
    it 'orders elements in non-decreasing priority' do
      subject = MinHeap.new([[:a, 2], [:b, 1]])
      expect(subject.pop).to eq(:b)
      expect(subject.pop).to eq(:a)
    end
  end

end
