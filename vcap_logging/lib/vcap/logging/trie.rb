require 'vcap/logging/util'

module VCAP
  module Logging
    class TrieNode

      attr_accessor :token
      attr_accessor :key
      attr_accessor :value
      attr_accessor :parent
      attr_accessor :children

      def initialize(token, value, parent=nil, key=nil)
        @token    = token
        @value    = value
        @parent   = parent
        @key      = key
        @children = {}
      end
    end

    # Rudimentary Trie implementation used for managing a hierarchy of loggers.
    #
    # Yes, it's not space-efficient (we store full keys along with the nodes, instead of
    # reconstructing them using the path), for the following reasons:
    #   1. I don't anticipate that we'll be storing more than 10s of loggers.
    #   2. Its utility is derived mainly from the ease of mapping over child nodes (needed
    #      for inserting loggers in the middle of an existing hierarchy) and finding the
    #      parent of a newly inserted logger.
    #
    class Trie

      DEFAULT_DELIMETER = '.'

      # @param  delim       String      Delimeter used to tokenize paths
      # @param  root_value  root_value  Value to be stored at the root of the trie
      def initialize(delim=DEFAULT_DELIMETER, root_value=nil)
        @delim = delim
        @root  = TrieNode.new(nil, root_value)
      end

      # Finds data at position specified by _name_
      #
      # @param  String   key  Key to look up (separated by @delim)
      #
      # @return Object        Stored value if key exists
      #         nil           Otherwise
      def get(key)
        VCAP::Logging.assert_kind_of('key', key, String)

        tokens = key.split(@delim)
        node   = find_node(@root, tokens)

        node ? node.value : nil
      end

      # Adds _val_ to the trie at the position specified by _key_
      #
      # @param  key   String  Key to use when storing the value (separated by @delim)
      # @param  val   Object  Value to store alongside key. CANNOT be nil.
      #
      # @return Object        Value that may have previously existed
      #         nil           Otherwise
      def put(key, val)
        VCAP::Logging.assert_kind_of('key', key, String)
        raise ArgumentError, "Value cannot be nil" if val == nil

        tokens     = key.split(@delim)
        node       = @root
        old_logger = nil

        for tok in tokens
          node.children[tok] = TrieNode.new(tok, nil, node) unless node.children[tok]
          node = node.children[tok]
        end

        old_val    = node.value
        node.key   = key
        node.value = val

        old_val
      end

      # Removes _key_ and the associated value
      #
      # @param  key  String   Key to remove (separated by @delim)
      #
      # @return Object        Value stored with Key
      #         nil           If key didn't exist
      def delete(key)
        VCAP::Logging.assert_kind_of('key', key, String)

        tokens = key.split(@delim)
        node   = find_node(@root, tokens)
        return nil if (node == nil) || (node.value == nil)

        old_val    = node.value
        node.key   = nil
        node.value = nil

        # Remove empty paths
        while node.children.empty? && (node.value == nil) && (node != @root)
          parent = node.parent
          parent.children.delete(node.token)
          node = parent
        end

        old_val
      end


      # Maps the supplied block over all k/vs that are children of _key_
      #
      # @param  key   String   Key specifying the root to start from (separated by @delim)
      #                        NB: If _key_ is nil, then the root node will be used for
      #                            the iteration.
      # @param        Block    Block to be called with the child key/value
      #
      # @return nil
      def map_children(key=nil, &blk)
        VCAP::Logging.assert_kind_of('key', key, String) unless key == nil
        raise ArgumentError, "Block arity must be 2" unless blk.arity == 2

        if key == nil
          parent = @root
        else
          tokens = key.split(@delim)
          parent = find_node(@root, tokens)
          return nil unless parent
        end

        # Level-order traversal
        queue = parent.children.values
        while queue.length > 0
          node = queue.shift
          if node.value
            blk.call(node.key, node.value)
          else
            node.children.each {|_, c| queue << c }
          end
        end
      end

      # Maps the supplied block over all the k/vs that descend from _key_.
      #
      # @param  key   String  Key specifying the root to start the iteration from
      #                       NB: If _key_ is nil, then the root node will be used for
      #                           the iteration.
      # @param        Block   Block to be called with the descendant key/value
      #
      # @return nil
      def map_descendents(key=nil, &blk)
        VCAP::Logging.assert_kind_of('key', key, String) unless key == nil
        raise ArgumentError, "Block arity must be 2" unless blk.arity == 2

        if key == nil
          parent = @root
        else
          tokens = key.split(@delim)
          parent = find_node(@root, tokens)
          return nil unless parent
        end

        # Level-order traversal
        queue = parent.children.values
        while queue.length > 0
          node = queue.shift
          blk.call(node.key, node.value) if node.value
          node.children.each {|_, c| queue << c }
        end
      end

      # Returns the parent k/v
      #
      # @param  key  String  Key to fetch the parent for
      #
      # @return Array        Array of parent [key, value] (if parent exists)
      #         nil          Otherwise
      def get_parent(key)
        VCAP::Logging.assert_kind_of('key', key, String)

        tokens = key.split(@delim)
        node   = find_node(@root, tokens)
        return nil if node == nil

        node = node.parent
        while node != nil
          return [node.key, node.value] if node.value != nil
          node = node.parent
        end

        nil
      end

      private

      # @param  cur_node  TrieNode       Where to start the search
      # @param  tokens    Array[String]  Path to take
      #
      # @return TrieNode                 If path exists
      #         nil                      Otherwise
      def find_node(cur_node, tokens)
        for tok in tokens
          cur_node = cur_node.children[tok]
          # Not found
          break if cur_node == nil
        end
        cur_node
      end

    end # VCAP::Logging::Trie

  end
end
