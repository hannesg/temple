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
    
  end
  
  it "should generate ruby code" do
  
    filter = Temple::Filters::EmbeddedEngine.new do
    
      register 'ruby', Temple::Filters::EmbeddedEngine::CodeEngine.new
    
    end
    
    filter.call([:embedded, :engine, 'ruby', "foo\nbar"]).should == [:multi, [:code, "foo\nbar"] ]
  
  end
  
end
