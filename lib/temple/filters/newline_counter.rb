module Temple
  module Filters
    # A filter which counts how many lines a certain
    # expression will occupy.
    # 
    # @example counts :newline
    #   nc = NewlineCounter.new
    #   nc.call([:multi, [:newline] ])
    #   nc.newlines #=> 1
    #
    # @example counts :code / :dynamic
    #   nc = NewlineCounter.new
    #   nc.call([:code, 'foo\n\nbar'])
    #   nc.newlines #=> 2
    #
    class NewlineCounter < Temple::Filter
    
      # Remove most of the default things
      self.instance_methods.each do |m|
        m = m.to_s
        if m =~ /\Aon_/ and m != 'on_multi'
          eval "undef #{m}"
        end
      end

      # total number of lines
      attr_reader :newlines

      # number of lines before the first not-empty line will appear
      attr_reader :preceding_newlines

      # number of lines after the first not-empty line will appear
      attr_reader :succeding_newlines

      # did the expression contained only newlines?
      def only_newlines?
        return !@code_found
      end

      # Resets {#newlines}, {#preceding_newlines}, {#succeding_newlines} and {#only_newlines?}
      def reset!
        @code_found = false
        @newlines = 0
        @preceding_newlines = 0
        @succeding_newlines = 0
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

      # @private
      def on_newline
        newline!
        return [:newline]
      end

      # @private
      def on_dynamic(body)
        body.lines.each do |line|
          if line[-1,1] == NEWLINE
            newline!
          end
        end
        return [:dynamic,body]
      end

      # @private
      def on_code(body)
        body.lines.each do |line|
          if line != NEWLINE
            code!
          end
          if line[-1,1] == NEWLINE
            newline!
          end
        end
        return [:code,body]
      end
    
      NEWLINE = "\n"
      
      def unknown(*tree)
        # assume that not tag is passed without generating code
        code!
        tree.each do |x|
          if x.kind_of? Array
            call(x)
          end
        end
        return tree
      end
    
    private
      def initialize(*_)
        super
        reset!
      end

      def newline!
        if @code_found
          @succeding_newlines += 1
        else
          @preceding_newlines += 1
        end
        @newlines += 1
      end
      
      def code!
        @code_found = true
        @succeding_newlines = 0
      end
      
    end
  end
end
