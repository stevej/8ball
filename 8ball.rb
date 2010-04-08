require "java"
require 'pp'

class String
  def first
    self[0].chr
  end

  def last
    self[-1].chr
  end

  def wrap_with(wrapper)
    if wrapper.length == 2
      wrapper.first + self + wrapper.last
    elsif wrapper.length == 1
      wrapper + self + wrapper
    else
      raise "bad argument"
    end
  end
end

class Array
  def to_comma_list
    self.join(", ").wrap_with("()")
  end

  def wrap_with(wrapper)
    if wrapper.length == 2
      wrapper.first.to_a + self + wrapper.last.to_a
    elsif wrapper.length == 1
      wrapper.to_a + self + wrapper.to_a
    else
      raise "bad argument"
    end
  end
end

class EightBallVisitor
  include org.jruby.ast.visitor.NodeVisitor

  def visit(node)
    node.accept(self)
  end

  def visitRootNode(node)
    visit(node.bodyNode)
  end

  def visit_block_node(node)
    node.child_nodes.map { |x| visit(x) }
  end

  def visitNewlineNode(node)
    visit(node.nextNode)
  end

  def visitCallOneArgNode(node)
    visitCallNode(node)
  end

  def visitCallNode(node)
    mangle(node.getName) +
      "#{visit(node.receiverNode)},#{visit(node.argsNode.getLast).to_s}".wrap_with("()")
  end

  def visitFixnumNode(node)
    "#{node.value}"
  end

  def visitStrNode(node)
    node.value.wrap_with('"')
  end

  def mangle(method)
    method.gsub("+", "primplus") # might need this later, leaving it for now.
  end

  def visitClassNode(node)
    gather("this.define_class(\"#{node.getCPath.getName}\",",
           "function() {",
           visit(node.bodyNode),
           "})")
  end

  def visitDefnNode(node)
    compile_function(node.get_name, node.args_node.args, node.body_node)
  end

  def visitArgsNode(node)
    node.args.child_nodes.to_a.map {|x| x.name}.join(", ")
  end

  def visitLocalVarNode(node)
    node.get_name
  end

  def gather(*args)
    args
  end

  def gather_with(str, *args)

  end

  def compile_function(name, args, body)
    gather("function #{name}#{compile_arglist(args)}",
           compile_function_body(body).wrap_with(["{\n", "\n}\n"]))
  end

  def compile_arglist(node)
    node.child_nodes.to_a.map {|x| x.name}.to_comma_list
  end

  def compile_function_body(node)
    if node.is_a? Java::OrgJrubyAst::BlockNode
      gather( [node.child_nodes.to_a[0..-2].map { |n| visit(n) } +
              ["return #{visit(node.child_nodes.to_a.last)}"]].join(";\n"))
    else
      "return #{visit(node)}"
    end
  end
end


class EightBallCompiler
  def self.parse(ruby)
    r = org.jruby.Ruby.getDefaultInstance
    r.parse(ruby, "test_code", r.getCurrentContext.getCurrentScope, 0, true)
  end

  def self.compile_string(ruby)
    parse(ruby).accept(EightBallVisitor.new)
  end

  def self.compile_file(file_name)
    prelude + compile_string(File.read(file_name))
  end

  def prelude
    # this outputs the js runtime we need.
    [File.read("lib.js"),
     File.read("primitives.js")].join("\n")
  end
end
