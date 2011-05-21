require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe VCAP::Logging::Trie do
  before :each do
    @trie = VCAP::Logging::Trie.new
  end

  describe '#put' do
    it 'raises an exception if supplied with a non-string key' do
      lambda { @trie.put(['a'], 'b') }.should raise_error(ArgumentError)
    end

    it 'raises an exception if supplied with a nil value' do
      lambda { @trie.put('a', nil) }.should raise_error(ArgumentError)
    end

    it 'correctly adds leaf keys' do
      @trie.put('foo.bar', 1).should == nil
      @trie.get('foo.bar').should == 1
    end

    it 'correctly adds keys corresponding to internal nodes' do
      @trie.put('foo.bar', 1).should == nil
      @trie.get('foo.bar').should == 1
      @trie.put('foo', 2).should == nil
      @trie.get('foo').should == 2
    end

    it 'replaces old values' do
      @trie.put('foo.bar', 1).should == nil
      @trie.get('foo.bar').should == 1
      @trie.put('foo.bar', 2).should == 1
      @trie.get('foo.bar').should == 2
    end
  end

  describe '#get' do
    it 'raises an exception if supplied with a non-string key' do
      lambda { @trie.get(['a']) }.should raise_error(ArgumentError)
    end

    it 'returns nil for unknown keys' do
      @trie.get('abc').should == nil
      @trie.get('').should == nil
    end

    # ehhh - this is already tested above...
    it 'finds existing keys' do
      @trie.put('foo.bar', 1).should == nil
      @trie.get('foo.bar').should == 1
    end

    it 'returns nil for paths internal nodes with no values' do
      @trie.put('foo.bar', 1).should == nil
      @trie.get('foo.bar').should == 1
      @trie.get('foo').should == nil
    end
  end

  describe '#delete' do
    it 'raises an exception if supplied with a non-string key' do
      lambda { @trie.delete(['a']) }.should raise_error(ArgumentError)
    end

    it 'returns nil for unknown keys' do
      @trie.delete('a').should == nil
    end

    it 'clears values for internal nodes with children' do
      @trie.put('foo.bar', 1).should == nil
      @trie.get('foo.bar').should == 1
      @trie.put('foo', 2).should == nil
      @trie.get('foo').should == 2
      @trie.delete('foo').should == 2
      @trie.get('foo').should == nil
      @trie.get('foo.bar').should == 1
    end

    it 'removes empty paths' do
      @trie.put('foo.bar.baz', 1).should == nil
      @trie.get('foo.bar.baz').should == 1
      @trie.put('foo.bar.jaz', 2).should == nil
      @trie.get('foo.bar.jaz').should == 2
      @trie.put('foo.bar', 3).should == nil
      @trie.get('foo.bar').should == 3

      root = @trie.instance_variable_get(:@root)

      @trie.delete('foo.bar.baz').should == 1
      root.children['foo'].should_not == nil
      root.children['foo'].children['bar'].should_not == nil
      root.children['foo'].children['bar'].children['baz'].should == nil
      root.children['foo'].children['bar'].children['jaz'].should_not == nil

      @trie.delete('foo.bar.jaz').should == 2
      root.children['foo'].should_not == nil
      root.children['foo'].children['bar'].should_not == nil
      root.children['foo'].children['bar'].children['baz'].should == nil
      root.children['foo'].children['bar'].children['jaz'].should == nil

      @trie.delete('foo.bar').should == 3
      root.children['foo'].should == nil
    end
  end

  describe 'get_parent' do
    it 'raises an exception if supplied with a non-string key' do
      lambda { @trie.get_parent(['a']) }.should raise_error(ArgumentError)
    end

    it 'returns nil for unknown keys' do
      @trie.get_parent('a').should == nil
    end

    it 'returns nil for keys with no parent' do
      @trie.put('a', 1).should == nil
      @trie.get('a').should == 1
      @trie.get_parent('a').should == nil
      @trie.get_parent('a.b').should == nil
    end

    it 'returns the correct parent of a key' do
      @trie.put('a', 1).should == nil
      @trie.get('a').should == 1
      @trie.put('a.b.c.d.e', 2).should == nil
      @trie.get('a.b.c.d.e').should == 2
      @trie.get_parent('a.b.c.d.e').should == ['a', 1]
    end

    it 'should return the updated parent if the original is deleted' do
      @trie.put('a', 1).should == nil
      @trie.get('a').should == 1
      @trie.put('a.b.c', 2).should == nil
      @trie.get('a.b.c').should == 2
      @trie.put('a.b.c.d.e', 3).should == nil
      @trie.get('a.b.c.d.e').should == 3
      @trie.get_parent('a.b.c').should == ['a', 1]
      @trie.get_parent('a.b.c.d.e').should == ['a.b.c', 2]
      @trie.delete('a.b.c').should == 2
      @trie.get_parent('a.b.c.d.e').should == ['a', 1]
    end
  end

  describe 'map_children' do
    it 'raises an exception if supplied with a non-string key' do
      lambda { @trie.map_children(['a']) {} }.should raise_error(ArgumentError)
    end

    it 'raises an exception if supplied with a block of the wrong arity' do
      lambda { @trie.map_children('a') {|x| x } }.should raise_error(ArgumentError)
    end

    it 'visits only the children' do
      @trie.put('a', 1).should == nil
      @trie.get('a').should == 1
      @trie.put('a.b.c', 2).should == nil
      @trie.get('a.b.c').should == 2
      @trie.put('a.b.f', 3).should == nil
      @trie.get('a.b.f').should == 3
      @trie.put('a.b.c.d.e', 4).should == nil
      @trie.get('a.b.c.d.e').should == 4

      visited = Set.new
      should_visit = Set.new(['a.b.c', 'a.b.f'])
      @trie.map_children('a') {|k, v| visited.add(k) }
      visited.should == should_visit
    end

    it 'visits top-level keys if supplied with nil' do
      @trie.put('a', 1).should == nil
      @trie.get('a').should == 1
      @trie.put('b', 1).should == nil
      @trie.get('b').should == 1
      @trie.put('c.d', 3).should == nil
      @trie.get('c.d').should == 3
      @trie.put('b.e', 2).should == nil
      @trie.get('b.e').should == 2

      visited = Set.new
      should_visit = Set.new(['a', 'b', 'c.d'])
      @trie.map_children(nil) {|k, v| visited.add(k) }
      visited.should == should_visit
    end
  end

  describe 'map_descendents' do
    it 'raises an exception if supplied with a non-string key' do
      lambda { @trie.map_descendents(['a']) {} }.should raise_error(ArgumentError)
    end

    it 'raises an exception if supplied with a block of the wrong arity' do
      lambda { @trie.map_descendents('a') {|x| x } }.should raise_error(ArgumentError)
    end

    it 'visits all descendents' do
      @trie.put('a', 1).should == nil
      @trie.get('a').should == 1
      @trie.put('a.b.c', 2).should == nil
      @trie.get('a.b.c').should == 2
      @trie.put('a.b.f', 3).should == nil
      @trie.get('a.b.f').should == 3
      @trie.put('a.b.c.d.e', 4).should == nil
      @trie.get('a.b.c.d.e').should == 4

      visited = Set.new
      should_visit = Set.new(['a.b.c', 'a.b.f', 'a.b.c.d.e'])
      @trie.map_descendents('a') {|k, v| visited.add(k) }
      visited.should == should_visit
    end

    it 'visits all keys if supplied with nil' do
      @trie.put('a', 1).should == nil
      @trie.get('a').should == 1
      @trie.put('b', 1).should == nil
      @trie.get('b').should == 1
      @trie.put('c.d', 3).should == nil
      @trie.get('c.d').should == 3
      @trie.put('b.e', 2).should == nil
      @trie.get('b.e').should == 2

      visited = Set.new
      should_visit = Set.new(['a', 'b', 'c.d', 'b.e'])
      @trie.map_descendents(nil) {|k, v| visited.add(k) }
      visited.should == should_visit
    end
  end
end
