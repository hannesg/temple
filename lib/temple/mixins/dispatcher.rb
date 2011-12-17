module Temple
  module Mixins
    # @api private
    class DispatchTreeNode

      attr_writer :value
      attr_reader :value

      def initialize
        @children = Hash.new{|hsh,key| hsh[key] = DispatchTreeNode.new}
        @value = nil
      end

      def [](key)
        @children[key.to_sym]
      end

      def compile(level = 0)
        if @children.empty?
          if @value
            return ("  "*level) + "return #{@value}( *exp[#{level}..-1] )"
          else
            raise "WAAAAAAAAAAA"
          end
        end
        code = [("  "*level) + "case(exp[#{level}])"]
        @children.each do |key, value|
          code << ("  " * level) + "when #{key.inspect} then"
          code << value.compile(level+1)
        end
        if @value
          code << ("  " * level) + "else"
          code << ("  " * level) + "  return #{@value}( *exp[#{level}..-1] )"
        end
        code << ("  "*level) + "end"
        return code.join "\n"
      end
    end

    # @api private
    module CoreDispatcher
      def on_multi(*exps)
        multi = [:multi]
        exps.each {|exp| multi << compile(exp) }
        multi
      end

      def on_capture(name, exp)
        [:capture, name, compile(exp)]
      end
    end

    # @api private
    module EscapeDispatcher
      def on_escape(flag, exp)
        [:escape, flag, compile(exp)]
      end
    end

    # @api private
    module ControlFlowDispatcher
      def on_if(condition, *cases)
        [:if, condition, *cases.compact.map {|e| compile(e) }]
      end

      def on_case(arg, *cases)
        [:case, arg, *cases.map {|condition, exp| [condition, compile(exp)] }]
      end

      def on_block(code, content)
        [:block, code, compile(content)]
      end

      def on_cond(*cases)
        [:cond, *cases.map {|condition, exp| [condition, compile(exp)] }]
      end
    end

    # @api private
    module CompiledDispatcher
      def call(exp)
        compile(exp)
      end

      def compile(exp)
        dispatcher(exp)
      end

      private

      def dispatcher(exp)
        replace_dispatcher(exp)
      end

      def replace_dispatcher(exp)
        types = DispatchTreeNode.new
        dispatched_methods.each do |method|
          method_types = method.split('_')
          method_types.shift # remove first
          method_types.inject(types){|tmp, type| tmp[type.to_sym] }.value = method
        end
        self.class.class_eval %{
          def dispatcher(exp)
            if self.class == #{self.class}
              #{types.compile(0)}
              return exp
            else
              replace_dispatcher(exp)
            end
          end
        }
        dispatcher(exp)
      end

      # @api private
      # returns the methods which will be dispatched
      def dispatched_methods
        rx = /^on(_[a-z]+)*$/
        self.methods(true).map(&:to_s).select(&rx.method(:=~))
      end
    end

    # @api private
    module Dispatcher
      include CompiledDispatcher
      include CoreDispatcher
      include EscapeDispatcher
      include ControlFlowDispatcher
    end
  end
end
