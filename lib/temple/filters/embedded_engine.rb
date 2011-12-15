require 'delegate'
module Temple
  module Filters
    # Embeds multiple engines
    class BareEmbeddedEngine < Filter

      # Yep, we dispatch inside html, too.
      # This is pointful, since embeds should happen 
      # _before_ expanding html, espacially when wrapping
      # in tags.
      include HTML::Dispatcher

      # Helps to modifiy the available engines.
      # 
      # This module is used by all subclasses of {BareEmbeddedEngine}
      # to manage the available engines.
      # 
      # @example
      #   class MyEmbeddedEngine < Temple::Filters::EmbeddedEngine
      #     
      #     # register a tilt engine:
      #     register :foo, Temple::Filters::EmbeddedEngine::TiltEngine
      #     # disables ruby engine (which is one of the default engines):
      #     disable  :ruby
      #     # wraps the erb-engine inside an html tag:
      #     register :erb, Temple::Filters::EmbeddedEngine::WrapTagEngine, :tag => 'erb'
      #     # changes the tagname for the javascript engine:
      #     register :javascript, :tag => 'javascript'
      #     # replace a default engine ( use tilted scss for all css) :
      #     replace  :css, Temple::Filters::EmbeddedEngine::TiltEngine, :as => 'scss'
      #     
      #   end
      # 
      module EngineRegistererModule

        # Registers an engine, a wrapper, additional options or
        # which supplied options to use.
        # 
        # This method will use the default engines. This means
        # if you supply a i.e. a hash of options, these options
        # will override global options but not which wrappers 
        # are used or which engine is used and so on.
        # If you don't want that, the use {#replace}
        # 
        def register(name, *args)
          name = name.to_s
          hash = {}
          options = []
          if own_engines[name]
            args.push(*own_engines[name])
          else
            if default_engines[name]
              args.push(default_engines[name])
            end
          end
          args.each do |arg|
            if arg.kind_of? Hash
              hash = arg.merge(hash)
            else
              options << arg
            end
          end
          if hash.any?
            options << hash
          end
          if own_engines[name]
            own_engines[name].replace( options )
          else
            own_engines[name] = options
          end
        end

        # Replaces an engine which new settings.
        def replace(name, *options)
          name = name.to_s
          if own_engines[name]
            own_engines[name].replace( options )
          else
            own_engines[name] = options
          end
        end

        # Enables an engine.
        # Has no effect unless default engines are disabled.
        def enable(name)
          register name
        end

        # Disable an engine.
        def disable(name)
          own_engines[name.to_s] = nil
        end

        def engine(name)
          name = name.to_s
          if own_engines[name]
            own_engines[name]
          else
            own_engines[name] ||= [ default_engines[name] ]
          end
        end

        def reset_engines!
          own_engines.clear
        end

        def engines
          @engines ||= MutableHash.new(own_engines, default_engines)
        end

        alias wrap register
        alias engine_options register

      end
      
      extend EngineRegistererModule

      class EngineRegisterer

        include EngineRegistererModule

        def initialize(own_engines, default_engines = {})
          @own_engines = own_engines
          @default_engines = default_engines
        end

      protected

        attr_reader :own_engines, :default_engines

      end

      # The base for all used engines.
      # Does nothing but passing thru the original content.
      class Engine

        include Temple::Mixins::Options

        def call(name, content)
          return content
        end

      end

      # An engine which forces pure static input and wraps the content in a :code expression
      class CodeEngine < Engine

        def call(name, content)
          ex = OnlyStatic::Enforce.new
          ex.call(content)
          text = ex.text
          if text.size == 0
            # no code.
            return ex.recover_newlines()
          end
          return ex.recover_newlines([:code , text])
        end
      
      end

      # An engine which uses a tilt engine as backend.
      # This version renders the content at compile time
      # and embeds it as static text.
      class TiltEngine < Engine

        def call(name, content)
          tilt_name = options[:as] || name
          tilt_engine = Tilt[tilt_name]
          raise "Cannot find a tilt engine named #{tilt_name}." unless tilt_engine
          tilt_options = options.to_hash
          
          ex = OnlyStatic::IgnoreDynamic.new
          ex.call(content)
          return ex.recover_newlines( tilt_render(tilt_engine, tilt_options, name, content) )
        end

      protected
        def tilt_render(tilt_engine, tilt_options, name, content)
          ex = OnlyStatic::Enforce.new
          ex.call(content)
          content = tilt_engine.new(tilt_options){ ex.text }.render
          return [:static, content ]
        end

      end

      # An engine which extracts the ruby source
      # generated by Tilt. This way the ruby source is
      # directly embedded into the resulting source,
      # which leads to nice performance.
      # 
      # This however only works for static content and
      # compiling tilt engines.
      class PrecompiledTiltEngine < TiltEngine

      protected

        def tilt_render(tilt_engine, tilt_options, name, content)
          ex = OnlyStatic::Enforce.new
          ex.call(content)
          content, offset = tilt_engine.new(tilt_options){ ex.text }.send(:precompiled, {})
          # Trim preceding and succedding newline characters.
          # They will be reinserted anyway, if they were present.
          content = content.dup
          content.chomp!
          # Okay, now squeeze out the offset ( yep, ugly! )
          if offset > 0
            lines = content.lines.to_a
            preamble = lines[0...offset].map{|line| line[-1,1] == "\n" ? line[0..-2] : line }
            content = preamble.join(';') + lines[offset..-1].join
          end
          return [:dynamic, content]
        end

      end

      # An engine which wraps another engine.
      # This is mainly used to surround output with html tags
      # or add interpolation.
      #
      # Concrete implementations should overwrite {#preprocess}
      # and/or {#postprocess}.
      #
      # @abstract
      class WrapEngine < Delegator

        # [BUG] Jruby doens't do this by default:
        def initialize(inner)
          __setobj__(inner)
        end

        def call(name, content)
          return postprocess( name, __getobj__.call( name, preprocess(name, content) ) )
        end

      protected
        
        def __getobj__
          @__inner__
        end
        def __setobj__(inner)
          @__inner__ = inner
        end
      
        def preprocess(name, content)
          return content
        end

        def postprocess(name, content)
          return content
        end

      end

      # Wraps the output of another engine into
      # an html-tag.
      class WrapTagEngine < WrapEngine

      protected
        def postprocess(name, content)
          unless options[:tag]
            raise ArgumentError, "#{self.class} doesn't know which tag to use. Please supply a :tag option."
          end
          return [
            :html,
            :tag,
            options[:tag],
            ( options[:attributes].kind_of?(Hash) ? 
                [:html, :attrs, *options[:attributes].map{|k,v| [:html, :attr, k.to_s, [:static, v.to_s]]}] :
                [:html, :attrs]
            ),
            content]
        end
      end

      # Wraps another engine which only accepts static content.
      # Tries to recover dynamic content via #{OnlyStatic::MaskDynamic}.
      # 
      class WrapMaskEngine < WrapEngine
      
        def call(name, content)
          only_static = OnlyStatic::MaskDynamic.new
          static_content = only_static.call(content)
          converted_content = super(name, static_content )
          return only_static.recover( converted_content )
        end
      
      end

      #TODO: find a way to fetch the last Sexp-tree before the generator for a generic temple-engine
      class TempleEngine < Engine
      end
      
      class ErbEngine < TempleEngine
        def call(name, content)
          os = OnlyStatic::Enforce.new
          os.call(content)
          result = os.recover_newlines( Temple::ERB::Parser.new.call(os.text) )
          return result
        end
      end

      # 
      # @option :engines
      #
      def initialize(options = {}, *rest, &block)
        options = options.to_hash
        engines = {}
        if options[:engines]
          options[:engines].to_hash.each do |k,v|
            if v
              if v.kind_of? Symbol
                # ehhmmmm, puhhhhh
                v = self.class.const_get(v)
              end
              if v == true
                engines[k.to_s] = self.class.engines[k.to_s]
              elsif (v.kind_of? Class and v <= Engine)
                engines[k.to_s] = [v]
              elsif (v.kind_of? Class and v <= WrapEngine) or v.kind_of? Hash or v.kind_of? Array
                self.class.engines[k.to_s] ||= []
                engines[k.to_s] = [ v, self.class.engines[k.to_s] ]
              else
                raise "Unknown engine option: #{k.inspect} => #{v.inspect}"
              end
            else
              engines[k.to_s] = nil
            end
          end
        end
        if block_given?
          EngineRegisterer.new(engines,self.class.engines).instance_eval(&block)
        end
        @engines = ImmutableHash.new(engines.freeze,(options[:use_global_engines] == false) ? {} : self.class.engines)
        super(options, *rest)
      end

      def self.own_engines
        @own_engines ||= {}
      end

      def self.default_engines
        @default_engines ||= begin
          if self.superclass.respond_to? :engines
            self.superclass.engines
          else
            {}
          end
        end
      end

      attr_reader :engines

      def engine(name)
        engines[name.to_s]
      end

      def make_engine(name)
        args = engine(name)
        if args.nil?
          return nil
        end
        wrapper = []
        options = []
        engine = nil
        args.flatten.each do |arg|
          if arg.kind_of? Hash
            options << arg.dup
          elsif arg.kind_of? ImmutableHash
            options << arg
          elsif arg.kind_of? Class
            if arg <= WrapEngine
              wrapper.unshift( arg )
            else
              engine ||= arg
            end
          elsif arg.kind_of? Symbol
            options << { arg => self.options[arg] }
          end
        end
        engine ||= Engine
        return wrapper.inject( engine.new ImmutableHash.new(*options) ){|memo,klass|
          klass.new(memo)
        }
      end

      def on_embed(name, content)
        name = name.to_s
        # slim compat
        if options[:enable_engines]
          unless options[:enable_engines].include? name
            raise "Embedded engine #{name} is disabled"
          end
        elsif options[:disable_engines]
          if options[:disable_engines].include? name
            raise "Embedded engine #{name} is disabled"
          end
        end
        # search the engine in the options
        en = make_engine(name)
        if en
          return en.call(name, content)
        else
          raise "Embedded engine #{name} not found"
        end
      end
      
    end
    
    # EmbeddedEngine including some default engines.
    # This should be suitable for most cases.
    class EmbeddedEngine < BareEmbeddedEngine
    
      register :markdown,   WrapMaskEngine, TiltEngine
      register :textile,    WrapMaskEngine, TiltEngine
      register :rdoc,       WrapMaskEngine, TiltEngine
      register :creole,     WrapMaskEngine, TiltEngine
      register :wiki,       WrapMaskEngine, TiltEngine
      register :builder,    PrecompiledTiltEngine
      
      register :sass,       WrapTagEngine,  TiltEngine, :tag => 'style', :attributes => {'type' => 'text/css' }
      register :scss,       WrapTagEngine,  TiltEngine, :pretty, :tag => 'style', :attributes => {'type' => 'text/css' }
      
      # css and javascript code is simply surrounded with tags
      register :javascript, WrapTagEngine, :tag => 'script', :attributes => {'type' => 'text/javascript'}
      register :style,      WrapTagEngine, :tag => 'style', :attributes => {'type' => 'text/css' }
      
      # ruby code is embedded
      register :ruby,       CodeEngine
      register :erb,        ErbEngine

    end
  end
end
