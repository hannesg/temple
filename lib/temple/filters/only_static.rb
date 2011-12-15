module Temple
  module Filters
    # A filter which ensures, that only :static, :newline and :multi expression pass thru.
    #
    # Allows furthermore to access lists of all encountered statics and newlines and the joined
    # text of all statics.
    #
    # This is useful in every context, where _only_ static content can be used, like caching or
    # external processing.
    # 
    # @abstract
    class OnlyStatic < Temple::Filter

      # Making this a 
      self.instance_methods.each do |m|
        m = m.to_s
        if m =~ /\Aon_/ and m != 'on_multi'
          eval "undef #{m}"
        end
      end
      
      # A filter which raises an error whenever a dynamic expression is found.
      class Enforce < self
    
      protected
        def unknown(*content)
          raise Temple::InvalidExpression, "Only :multi, :static and :newline expressions are supported, but found #{content.inspect}."
        end
        
      end
      
      # A filter which allows to mask dynamic expression and tries to recover
      # them later.
      class MaskDynamic < self
      
        # @private
        CHARACTER_SET = ('a'..'z').to_a + ('A'..'Z').to_a
        
        def reset!
          super
          @expressions = []
          @prefix = ""
          @suffix = ""
        end
        
        def call(*_)
          result = super
          current_text = self.text
          loop do
            @prefix = (0..(3+rand(5))).map{|_| CHARACTER_SET[rand(CHARACTER_SET.size)] }.join
            break if !current_text.include?(@prefix) 
          end
          loop do 
            @suffix = (0..(3+rand(5))).map{|_| CHARACTER_SET[rand(CHARACTER_SET.size)] }.join
            break if !current_text.include?(@suffix) and @prefix != @suffix
          end
          
          @expressions.each_with_index do |(content, placeholder), i|
            placeholder[1] = "#{@prefix}#{i}#{@suffix}"
          end
          
          return result
        end
        
        # Recovers the inserted placeholders.
        # 
        # This equation is always true:
        # @example
        #   os = Temple::Filters::OnlyStatic::MaskDynamic.new
        #   os.recover( *os.call( *<any-expression> ) ) == <any-expression>
        #
        # Normally you would do something with the result of {#call} before
        # feeding it to recover.
        #
        def recover(tree)
          return tree if @expressions.empty?
          recovered = recover_exp(tree)
          recovered = StaticMerger.new.call( recovered ) 
          recovered = MultiFlattener.new.call( recovered ) 
          return recovered
        end
      
      protected
        def unknown(*content)
          placeholder = [:static, '']
          @expressions << [ content, placeholder ]
          @statics << placeholder
          return placeholder
        end
        
        def recover_exp(tree)
          if tree[0] == :static
            return recover_string(tree[1])
          else
            return tree.map do |x|
              if x.kind_of? Array
                recover_exp(x)
              else
                x
              end
            end
          end
        end
        
        def recover_string(str)
          multi = [:multi]
          while str.size > 0
            match = /#{@prefix}(\d+)#{@suffix}/.match(str)
            if match.nil?
              multi << [:static, str]
              return multi
            end
            if match.pre_match.size > 0
              multi << [:static, match.pre_match] 
            end
            multi << @expressions[match[1].to_i][0]
            str = match.post_match
          end
          return multi
        end
      end
      
      # A filter which simply ignores dynamics.
      class IgnoreDynamic < self
      
        NEWLINE = "\n"
      
      protected
        def unknown(*tree)
          return slurp_newlines(tree)
        end
        
        def slurp_newlines(tree, stack = [])
          if tree[0] == :newline
            stack << on_newline
          elsif tree[0] == :dynamic or tree[0] == :code
            tree[1].lines.each do |line|
              if line != NEWLINE
                on_static('')
              end
              if line[-1,1] == NEWLINE
                stack << on_newline
              end
            end
          else
            tree[1..-1].each do |x|
              if x.kind_of?(Array)
                slurp_newlines(x, stack)
              end
            end
          end
          return case(stack.size)
            when 0 then nil
            when 1 then stack[0]
            else [:multi, *stack]
          end
        end
      
      end

      # List of all static expression. They are guaranted to be in the order of their appereance.
      attr_reader :statics
      
      # Number of newline expression.
      attr_reader :newlines
      
      attr_reader :preceding_newlines
      
      attr_reader :succeding_newlines

      # Resets {#statics}, {#newlines} and {#text}.
      def reset!
        @statics = []
        @newlines = 0
        @preceding_newlines = 0
        @succeding_newlines = 0
      end
      
      def initialize
        reset!
      end

      # The joined text of all encountered statics.
      #
      # @example
      #   os = Temple::Filters::OnlyStatic::IgnoreDynamic.new
      #   os.call([:multi, [:static, "foo\n"], [:newline], ["static", "bar"]])
      #   os.text #=> "foo\nbar"
      #
      def text
        statics.map(&:last).join
      end

      # Tries to match the number of newlines in a tree with
      # the number of newlines in the tree supplied to the last
      # call. This is neccessary to keep correct line numberings
      # for following content.
      #
      # @example
      #   os = Temple::Filters::OnlyStatic::IgnoreDynamic.new
      #   os.call([:multi, [:newline], [:static, "abc"], [:newline]])
      #   os.text #=> "abc"
      #   # Do some uber-heavy string processing:
      #   new_tree = [:static, os.text.reverse]
      #   # et voila! Correct number of newlines:
      #   os.adjust_newlines(new_tree) #=> [:multi, [:newline], [:static, "cba"], [:newline]]
      # 
      # @see NewlineAdjuster
      def adjust_newlines(tree=nil, options={})
        newline_adjuster(options).call(tree)
      end
      
      # Creates a {NewlineAdjuster} with the settings
      # of this filter ( number of newlines, preceding
      # newlines ... )
      def newline_adjuster(options={})
        NewlineAdjuster.new({:newlines => newlines, :preceding_newlines => preceding_newlines, :succeding_newlines => succeding_newlines}.merge(options))
      end
      
      def on_newline
        if @statics.empty?
          @preceding_newlines += 1
        end
        @newlines += 1
        @succeding_newlines += 1
        return [:newline]
      end
      
      def on_static(body)
        @succeding_newlines = 0
        @statics << [:static, body]
        return [:static, body]
      end
      
      def on_multi(*exps)
        super.compact
      end
      
    end

    def OnlyStatic.new(*_)
      if self == OnlyStatic
        raise "OnlyStatic is abstract, please use a subclass."
      else
        return super
      end
    end

  end
end
