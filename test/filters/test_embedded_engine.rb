require 'helper'

describe Temple::Filters::EmbeddedEngine do
  before do
    @filter = Temple::Filters::EmbeddedEngine.new
  end
  
  describe "globaly registered engines" do
  
    it "should be used" do
    
      Temple::Filters::EmbeddedEngine.register 'ruby', :foo
      
      filter = Temple::Filters::EmbeddedEngine.new
      
      filter.options[:engines]['ruby'].should == :foo
    
    end
    
    it "should be used even if added later" do
    
      Temple::Filters::EmbeddedEngine.register 'ruby', :foo
      
      filter = Temple::Filters::EmbeddedEngine.new
      
      Temple::Filters::EmbeddedEngine.register 'baz', :bar
      
      filter.options[:engines]['baz'].should == :bar
    
    end
    
    it "should be overrideable" do
    
      Temple::Filters::EmbeddedEngine.register 'ruby', :foo
      
      filter = Temple::Filters::EmbeddedEngine.new( :engines => {'ruby' => nil, 'foo' => :foo} )
      
      filter.options[:engines]['ruby'].should == nil
      filter.options[:engines]['foo'].should == :foo
    
    end
    
    it "should be overrideable with blocks" do
    
      Temple::Filters::EmbeddedEngine.register 'ruby', :foo
      
      filter = Temple::Filters::EmbeddedEngine.new do
        
        register 'ruby', nil
        
        register 'foo', :foo
        
      end
      
      filter.options[:engines]['ruby'].should == nil
      filter.options[:engines]['foo'].should == :foo
    
    end
  
    it "should be possible to completly ignore global engines" do

      Temple::Filters::EmbeddedEngine.register 'foo', :foo

      filter = Temple::Filters::EmbeddedEngine.new(:use_global_engines => false)

      filter.options[:engines]['foo'].should.be.nil

    end

    it "should be able to allow global engines selectivly" do

      Temple::Filters::EmbeddedEngine.register 'foo', :foo
      Temple::Filters::EmbeddedEngine.register 'bar', :bar

      filter = Temple::Filters::EmbeddedEngine.new(:use_global_engines => false) do
	allow 'foo'
      end

      filter.options[:engines]['foo'].should == :foo
      filter.options[:engines]['bar'].should.be.nil

    end
 
    it "should be able to deny global engines selectivly" do

      Temple::Filters::EmbeddedEngine.register 'foo', :foo
      Temple::Filters::EmbeddedEngine.register 'bar', :bar

      filter = Temple::Filters::EmbeddedEngine.new() do
        deny 'bar'
      end

      filter.options[:engines]['foo'].should == :foo
      filter.options[:engines]['bar'].should.be.nil

    end
    it "should be wrappable" do

      Temple::Filters::EmbeddedEngine.register 'foo',:fooo
 
      filter = Temple::Filters::EmbeddedEngine.new do

        wrap 'foo', Temple::Filters::EmbeddedEngine::WrapTagEngine.new(:tag=>'foo')

      end

      filter.options[:engines]['foo'].inner.should == Temple::Filters::EmbeddedEngine.engine('foo')

   end
 
  end
  
  describe "inside an engine" do
  
    it "should be awesome" do
    
      class FooEngine < Temple::Engine
      
        filter :EmbeddedEngine
      
      end
    


    end
  
  end

  describe "wrapping" do

    it "should be possible to wrap an arbitrary engine in an html tag" do
      filter = Temple::Filters::EmbeddedEngine.new do
        register 'wruby', Temple::Filters::EmbeddedEngine::WrapTagEngine.new( :engine => Temple::Filters::EmbeddedEngine::CodeEngine.new, :tag=> 'ruby', :attributes => {:foo => 'bar'} )
      end

      filter.call([:embed, 'wruby', [:multi, [:static, "bar"]]]).should == [:html, :tag , 'ruby', [:html, :attrs, [:html, :attr, 'foo', [:static, 'bar']]], [:code, 'bar']]

    end

  end

  it "should generate ruby code" do
  
    filter = Temple::Filters::EmbeddedEngine.new do
    
      register 'ruby', Temple::Filters::EmbeddedEngine::CodeEngine.new
    
    end
    
    filter.call([:embed, 'ruby',[:multi, [:static, "foo\nbar"]]]).should == [:code, "foo\nbar"]
  
  end
  
  it "should protect expressions in tilt engines" do
  
    filter = Temple::Filters::EmbeddedEngine.new do
    
      register 'markdown', Temple::Filters::EmbeddedEngine::ProtectingTiltEngine.new
    
    end
    
    filter.call([:embed, 'markdown',[:multi, [:static, "foo\nbar"],[:dynamic,"1+2"]]]).should == [:multi]
  
  end
  
  
  
end
