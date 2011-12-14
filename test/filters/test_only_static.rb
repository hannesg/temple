describe Temple::Filters::OnlyStatic do

  describe Temple::Filters::OnlyStatic::IgnoreDynamic do
  
    it "should ignore dynamics" do
    
      os = Temple::Filters::OnlyStatic::IgnoreDynamic.new
      
      os.call(:multi, [:newline], [:static, "foo"], [:foo]).should == [:multi, [:newline], [:static, "foo"]]
    
    end
    
    it "should ignore statics inside dynamics" do
    
      os = Temple::Filters::OnlyStatic::IgnoreDynamic.new
      
      os.call(:multi, [:newline], [:static, "foo"], [:foo, [:static, "foo"]]).should == [:multi, [:newline], [:static, "foo"]]
    
    end
    
    describe "line counting" do
    
      it "should count dynamics with succeding newline correctly" do
      
        os = Temple::Filters::OnlyStatic::IgnoreDynamic.new
        
        os.call(:dynamic, "\nfoo\nbar\n")
        
        os.preceding_newlines.should == 1
        os.newlines.should == 3
        os.succeding_newlines.should == 1
      
      end
      
      it "should count dynamics without succeding newline correctly" do
      
        os = Temple::Filters::OnlyStatic::IgnoreDynamic.new
        
        os.call(:dynamic, "\nfoo\nbar")
        
        os.preceding_newlines.should == 1
        os.newlines.should == 2
        os.succeding_newlines.should == 0
      
      end
      
      it "should count dynamics with preceding newline correctly" do
      
        os = Temple::Filters::OnlyStatic::IgnoreDynamic.new
        
        os.call(:dynamic, "\n\n \n\nfoo\nbar")
        
        os.preceding_newlines.should == 2
        os.newlines.should == 5
      
      end
  
    end
  
  end
  
  describe Temple::Filters::OnlyStatic::Enforce do
  
    it "should raise on dynamics" do
    
      os = Temple::Filters::OnlyStatic::Enforce.new
      
      should.raise(Temple::InvalidExpression){
        os.call(:multi, [:newline], [:static, "foo"], [:foo])
      }
      
    end
    
  
  end
  
  describe Temple::Filters::OnlyStatic::MaskDynamic do
  
    it "should mask dynamics and should make it possible to recover it" do
    
      os = Temple::Filters::OnlyStatic::MaskDynamic.new
      
      data = [:multi, [:newline], [:static, "foo"], [:foo]]
      
      os.recover( *os.call(*data) ).should == data
      
    end
    
  
  end


end
