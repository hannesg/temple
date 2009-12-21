module Temple
  module Filters
    # Merges several statics into a single static.  Example:
    #
    #   [:multi,
    #     [:static, "Hello "],
    #     [:static, "World!"]]
    #
    # Compiles to:
    # 
    #   [:multi,
    #     [:static, "Hello World!"]]
    class StaticMerger
      def compile(exp)
        exp.first == :lines ? on_lines(*exp[1..-1]) : exp
      end
      
      def on_lines(*lines)
        res = [:lines]
        curr_line = nil
        curr = nil
        state = :looking
        
        lines.each do |line|
          res << (curr_line = [])
          line.each do |exp|
            if exp.first == :static
              if state == :looking
                curr_line << [:static, (curr = exp[1].dup)]
                state = :static
              else
                curr << exp[1]
              end
            else
              curr_line << compile(exp)
              state = :looking
            end
          end
        end
        
        res
      end
    end
  end
end