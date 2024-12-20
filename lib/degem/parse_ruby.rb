# frozen_string_literal: true

module Degem
  class ParseRuby
    def initialize(visitor = Visitor)
      @visitor = visitor
    end

    def call(path)
      visitor = @visitor.new
      Array(path).each do |path|
        visitor.path = path
        Prism.parse_file(path).value.accept(visitor)
        Degem.stderr.putc "."
      end
      visitor
    end
  end

  require "prism"

  class Visitor < Prism::Visitor
    def initialize
      @requires = Set.new
      @paths = Set.new
      @classes = Set.new
      @modules = Set.new
      @path = nil
      @stack = []
      super
    end

    def requires = @requires.to_a
    def consts = (@paths.union(@classes).union(@modules)).to_a
    def paths = @paths.to_a
    def classes = @classes.to_a
    def modules = @modules.to_a
    attr_writer :path

    def visit_call_node(node)
      visit_require_call_node(node)
      super
    end

    def visit_module_node(node)
      @stack.push(node)
      super
      @modules.add(@stack.map(&:name).join("::"))
      @stack.pop
    end

    def visit_class_node(node)
      @stack.push(node)
      super
      @stack.pop
      *modules, klass = node.constant_path.full_name_parts rescue [[], node.name]
      @modules.add((@stack.map(&:name) + modules).join("::")) if modules.any?
      @classes.add((@stack.map(&:name) + modules + [klass]).join("::"))
    end

    def visit_constant_path_node(node)
      paths_from(node).each { @paths.add(_1) }
      super
    end

    def visit_constant_read_node(node)
      @paths.add(node.name.to_s) unless @stack.find { _1.constant_path == node }
      super
    end

    private

    def visit_require_call_node(node)
      return if node.name.to_s != "require"
      return if node.receiver
      return unless node.arguments
      return unless node.arguments.arguments[0].is_a?(Prism::StringNode)

      required = node.arguments.arguments[0].unescaped
      @requires.add(required)
    end

    def from_ancestor_to(node)
      acc = [node]
      node = node.respond_to?(:parent) && node.parent
      while node
        acc.prepend(node)
        node = node.respond_to?(:parent) && node.parent
      end
      acc
    end

    def paths_from(node)
      from_ancestor_to(node)
        .filter_map { _1.respond_to?(:name) ? _1.name.to_s : nil }
        .tap { _1.singleton_class.include(Scan) }
        .scan { |a, b| [a, b].join("::") }
    end
  end

  module Scan
    def scan(init = nil)
      if init.nil?
        init = self[0]
        xs = self[1..] || []
      else
        xs = self
      end

      return self if xs.empty?

      xs.reduce([init]) do |acc, x|
        acc + [yield(acc.last, x)]
      end
    end
  end
end
