require 'helper'

describe Temple::Filters::EmbeddedEngine do

  class SimpleTestEngine < Temple::Engine

    class Parser

      include Temple::Mixins::Options

      def call(exp)
        return [:static, exp.to_s ]
      end

    end

    use Parser

    generator :ArrayBuffer

  end

  Temple::Templates::Tilt(SimpleTestEngine, :register_as => '__ste__')

  before do
    @filter = Temple::Filters::EmbeddedEngine.new
  end

  describe "globaly registered engines" do

    class ShadyEmbeddedEngine < Temple::Filters::BareEmbeddedEngine

    end

    before do
      ShadyEmbeddedEngine.reset_engines!
    end

    it "should be used" do

      ShadyEmbeddedEngine.register 'ruby', :foo

      filter = ShadyEmbeddedEngine.new

      filter.engine('ruby').should == [:foo]

    end

    it "should be used even if added later" do

      ShadyEmbeddedEngine.register 'ruby', :foo

      filter = ShadyEmbeddedEngine.new

      ShadyEmbeddedEngine.register 'baz', :bar

      filter.engine('baz').should == [:bar]

    end

    it "should be overrideable" do

      ShadyEmbeddedEngine.register 'ruby', :foo

      filter = ShadyEmbeddedEngine.new( :engines => {'ruby' => nil, 'foo' => :TiltEngine} )

      filter.engine('ruby').should == nil
      filter.engine('foo').should == [Temple::Filters::EmbeddedEngine::TiltEngine]

    end

    it "should be overrideable with blocks" do

      ShadyEmbeddedEngine.register 'ruby', :foo

      filter = ShadyEmbeddedEngine.new do

        replace 'ruby', :baz
        register 'foo', :foo

      end

      filter.engine('ruby').should == [:baz]
      filter.engine('foo').should == [:foo]

    end

    it "should be possible to completly ignore global engines" do

      ShadyEmbeddedEngine.register 'foo', :foo

      filter = ShadyEmbeddedEngine.new(:use_global_engines => false)

      filter.engine('foo').should.be.nil

    end

    it "should be able to allow global engines selectivly" do

      ShadyEmbeddedEngine.register 'foo', :foo
      ShadyEmbeddedEngine.register 'bar', :bar

      filter = ShadyEmbeddedEngine.new(:use_global_engines => false) do
        enable 'foo'
      end

      filter.engine('foo').flatten.should == [:foo]
      filter.engine('bar').should.be.nil

    end

    it "should be able to deny global engines selectivly" do

      ShadyEmbeddedEngine.register 'foo', :foo
      ShadyEmbeddedEngine.register 'bar', :bar

      filter = ShadyEmbeddedEngine.new() do
        disable 'bar'
      end

      filter.engine('foo').should == [:foo]
      filter.engine('bar').should.be.nil

    end
    it "should be wrappable" do

      ShadyEmbeddedEngine.register 'foo',:fooo

      filter = ShadyEmbeddedEngine.new do

        wrap 'foo', Temple::Filters::EmbeddedEngine::WrapTagEngine

      end

      filter.engine('foo').flatten.should == [Temple::Filters::EmbeddedEngine::WrapTagEngine, :fooo]

    end

    it "should be able to replace the engine in a subclass" do

      ShadyEmbeddedEngine.register 'foo', Temple::Filters::EmbeddedEngine::WrapTagEngine, Temple::Filters::EmbeddedEngine::Engine

      klass = Class.new(ShadyEmbeddedEngine) do

        register 'foo', Temple::Filters::EmbeddedEngine::TiltEngine

      end

      klass.engine('foo').should == [Temple::Filters::EmbeddedEngine::TiltEngine, [Temple::Filters::EmbeddedEngine::WrapTagEngine, Temple::Filters::EmbeddedEngine::Engine]]

    end

  end

  describe "wrapping" do

    it "should be possible to wrap an arbitrary engine in an html tag" do
      filter = Temple::Filters::EmbeddedEngine.new do
        register 'wruby', Temple::Filters::EmbeddedEngine::WrapTagEngine, Temple::Filters::EmbeddedEngine::CodeEngine, :tag=> 'ruby', :attributes => {:foo => 'bar'}
      end

      filter.call([:embed, 'wruby', [:multi, [:static, "bar"]]]).should == [:html, :tag , 'ruby', [:html, :attrs, [:html, :attr, 'foo', [:static, 'bar']]], [:code, 'bar']]

    end

  end

  describe "tilt" do

    it "should be able to use a precompiled engine" do

      filter = Temple::Filters::EmbeddedEngine.new do
        register '__ste__', Temple::Filters::EmbeddedEngine::PrecompiledTiltEngine
      end

      filter.call([:embed, '__ste__',[:multi, [:static, "foo\nbar"]]]).should == [:dynamic, SimpleTestEngine.new.call("foo\nbar") ]

    end

    it "should be able to use a non-precompiling engine" do

      filter = Temple::Filters::EmbeddedEngine.new do
        register '__ste__', Temple::Filters::EmbeddedEngine::TiltEngine
      end

      # Okay, this condition looks too trivial. Maybe add other Tilt engines??
      filter.call([:embed, '__ste__',[:multi, [:static, "foo"],[:newline],[:static,"bar"]]]).should == [:multi, [:static, "foobar"], [:newline]]

    end

  end

  describe Temple::Filters::EmbeddedEngine::CodeEngine do

    before do
      @code_engine = Temple::Filters::EmbeddedEngine::CodeEngine.new
    end

    it "should generate ruby code" do
      @code_engine.call( 'ruby',[:multi, [:static, "foo\n"],[:newline],[:static,"bar"]]).should == [:code, "foo\nbar"]
    end

    it "should add preceding newlines if they were present in the original content but not the resulting code" do

      # two :newline, but code will have only one:
      content = [:multi, [:newline], [:static, "a = 1"], [:newline], [:static, "\nmissing!"]]
      result = @code_engine.call("ruby", content)
      result.should == [:multi, [:newline], [:code, "a = 1\nmissing!"]]

    end

    it "should add succeding newlines if they were present in the original content but not the resulting code" do

      # two :newline, but code will have only one:
      content = [:multi, [:static, "a = 1"], [:newline], [:static, "\nmissing!"], [:newline]]
      result = @code_engine.call("ruby", content)
      result.should == [:multi, [:code, "a = 1\nmissing!"], [:newline]]

    end

    it "should work if the code only consists of newlines" do

      content = [:multi, [:newline], [:newline], [:newline] ]
      result = @code_engine.call("ruby", content)
      result.should == [:multi, [:newline], [:newline], [:newline]]

    end

  end

  describe Temple::Filters::EmbeddedEngine::WrapMaskEngine do

    it "should protect expressions in tilt engines" do

      filter = Temple::Filters::EmbeddedEngine.new do

        register '__ste__', Temple::Filters::EmbeddedEngine::WrapMaskEngine, Temple::Filters::EmbeddedEngine::TiltEngine

      end

      filter.call([:embed, '__ste__',[:multi, [:static, "foo\nbar"],[:foo]]]).should == [:multi, [:static, "foo\nbar"],[:foo]]

    end

  end

  describe Temple::Filters::EmbeddedEngine::ErbEngine do

    def generate(expression)

      expression = Temple::Filters::Escapable.new.call(expression)
      expression = Temple::Generators::StringBuffer.new.call(expression)
      return expression

    end

    it "should work" do

      content = [:multi, [:static, "hello <%== x %>\n"], [:newline]]

      result = Temple::Filters::EmbeddedEngine::ErbEngine.new.call('erb', content)

      code = generate(result)
      code.should == "_buf = ''; _buf << (\"hello \"); _buf << (( x ).to_s); _buf << (\"\\n\"); \n; _buf << (\"\"); _buf"

    end

  end

end
