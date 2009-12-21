module Temple
  class Generator
    DEFAULT_OPTIONS = {
      :buffer => "_buf"
    }
    
    def initialize(options = {})
      @options = DEFAULT_OPTIONS.merge(options)
    end
    
    def compile(exp)
      preamble + ';' + compile_part(exp) + ';' + postamble
    end
    
    def compile_part(exp)
      send("on_#{exp.first}", *exp[1..-1])
    end
    
    def buffer(str = '')
      @options[:buffer] + str
    end
    
    # Sensible defaults
    
    def preamble;  '' end
    def postamble; '' end
    
    def on_lines(*lines)
      lines.map { |line| line.map { |exp| compile_part(exp) }.join(";") }.join("\n")
    end
  end
end