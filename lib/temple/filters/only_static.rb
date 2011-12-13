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

      # A filter which raises an error whenever a dynamic expression is found.
      class Enforce < self
    
      protected
        def non_static(content)
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
        def recover(*tree)
          return tree if @expressions.empty?
          recovered = recover_exp(*tree)
          recovered = StaticMerger.new.call( recovered ) 
          recovered = MultiFlattener.new.call( recovered ) 
          return recovered
        end
      
      protected
        def non_static(content)
          placeholder = [:static, '']
          @expressions << [ content, placeholder ]
          @statics << placeholder
          return placeholder
        end
        
        def recover_exp(*tree)
          if tree[0] == :static
            return recover_string(tree[1])
          else
            return tree.map do |x|
              if x.kind_of? Array
                recover_exp(*x)
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
      
      protected
        def non_static(_)
          return nil
        end
      
      end

      # List of all static expression. They are guaranted to be in the order of their appereance.
      attr_reader :statics
      
      # List of all newline expression. They are guaranted to be in the order of their appereance.
      attr_reader :newlines

      # Resets {#statics}, {#newlines} and {#text}.
      # This method is called automatically before each call.
      def reset!
        @statics = []
        @newlines = []
      end

      # The joined text of all encountered statics.
      def text
        statics.map(&:last).join
      end

      def call(*content)
        reset!
        inner_call(*content)
      end

    protected
    
      def inner_call(*content)
        type = content[0]
        case type
        when :multi then
          return [:multi, *content[1..-1].map{|token| inner_call(*token) }.compact]
        when :static then
          @statics << content
          return content
        when :newline then
          @newlines << content
          return content
        else
          return non_static(content)
        end
      end
    
      def non_static(content)
        raise NotImplemented, "#{self.class}.non_static is not implemented. Please do so!"
      end
      
    end

    def OnlyStatic.new(*_)
      if self == OnlyStatic
        raise "OnlyStatic is abstract, please use a subclass (#{self})"
      else
        return super
      end
    end

  end
end
