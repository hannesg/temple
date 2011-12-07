module Temple
  module Filters
    # Embeds multiple engines
    class EmbeddedEngine < Filter
    
      class Registerer
      
        def initialize(hash)
          @hash = hash
        end
        
        def register(name, engine)
          @hash[name.to_s] = engine
        end
      
      end
    
      class Engine
        
        include Temple::Mixins::Options
        
        def call(name, content)
          return [:static, content]
        end
        
        def newlines(content)
          return Array.new(content.lines.count, [:newline])
        end
        
      end
      
      class CodeEngine < Engine
      
        def call(name, content)
          return [:code, content]
        end
        
      end
      
      class TiltEngine < Engine
      
        def call(name, content)
          tilt_engine = Tilt[name]
          return [ :multi, tilt_call(tilt_engine, name, content), *newlines(content) ]
        end
      
      end
      
      class PrecompiledTiltEngine < TiltEngine
        
        def tilt_call(tilt_engine, name, content)
          return [:dynamic, tilt_engine.new{ text }.send(:precompiled, {}).first]
        end
        
      end
      
      class WrapEngine < Engine
      
        def initialize(inner, *rest)
          @inner = inner
          super(*rest)
        end
      
        def call(name, content)
          return postprocess( name, @inner.call( name, preprocess(name, content) ) )
        end
        
        def preprocess(name, content)
          return content
        end
        
        def postprocess(name, content)
          return content
        end
      
      end
      
      def initialize(options = {}, *rest, &block)
        engines = options.key?(:engines) ? options[:engines].clone : {}
        if block_given?
          Registerer.new(engines).instance_eval(&block)
        end
        options[:engines] = ImmutableHash.new(engines.freeze, self.class.default_options[:engines])
        super(options, *rest)
      end
      
      self.default_options[:engines] = MutableHash.new
      
      def self.register(name, engine)
        self.default_options[:engines][name.to_s] = engine
      end
      
      def on_embedded_engine(name, content)
        name = name.to_s
        # search the engine in the options
        engine = options[:engines][name]
        if engine
          return engine.call(name, content)
        else
          raise ArgumentError, "Embedded engine #{name} not found"
        end
      end
    
    end
    
    
  end
end
