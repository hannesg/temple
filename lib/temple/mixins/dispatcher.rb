module Temple
  module Mixins
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
    
      include Utils
      
      def call(exp)
        compile(exp)
      end

      def compile(exp)
        dispatcher(exp)
      end

      private

      def case_statement(types, level, default = nil)
        code = "case exp[#{level}]\n"
        types.each do |name, method|
          code << "when #{name.to_sym.inspect}\n" <<
            (Hash === method ? case_statement(method, level + 1, default) : "on_#{method.join('_')}(*(exp[#{level+1}..-1]))\n")
        end
        if default
          code << "else\n#{default}(*exp)\nend\n"
        else
          code << "else\nexp\nend\n"
        end
      end

      def dispatcher(exp)
        replace_dispatcher(exp)
      end
      
      # Creates a tree from a list of symbol arrays.
      # 
      # @example
      #   Utils.dispatch_tree([:foo], [:bar, :baz]) #=> {:foo=>[:foo],:bar=>{:baz=>[:bar,:baz]}}
      # 
      def dispatch_tree(*args)
        types = {}
        args.each do |arg|
          if arg.kind_of?(Symbol)
            if types[arg].kind_of? Hash
              raise ArgumentError, "#{arg.inspect} conflicts with #{types[arg].inspect}"
            end
            types[arg] = [arg]
          elsif arg.kind_of?(Array) and arg.all?{|x| x.kind_of? Symbol } and arg.size > 0
            last = arg.last
            last_types = arg[0..-2].inject(types){|memo, sym|
              case(memo[sym])
                when Hash then memo[sym]
                when Array then raise ArgumentError, "#{arg.inspect} conflicts with #{memo[sym].inspect}"
                when nil then memo[sym] = {}
              end
            }
            last_types[last] = arg
          else
            raise ArgumentError, "Expected a symbol or an array of symbols, but got #{arg.inspect}."
          end
        end
        return types
      end
      
      def replace_dispatcher(exp)
        methods = []
        self.class.instance_methods.each do |method|
          next if method.to_s !~ /^on_(.*)$/
          methods << $1.split('_').map(&:to_sym)
        end
        self.class.class_eval %{
          def dispatcher(exp)
            if self.class == #{self.class}
              #{case_statement(dispatch_tree(*methods), 0, self.respond_to?(:unknow) ? 'unknown' : nil )}
            else
              replace_dispatcher(exp)
            end
          end
        }
        dispatcher(exp)
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
