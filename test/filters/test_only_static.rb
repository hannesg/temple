describe Temple::Filters::OnlyStatic do
  
  describe Temple::Filters::OnlyStatic::Enforce do
  
    it "should raise on dynamics" do
    
      os = Temple::Filters::OnlyStatic::Enforce.new
      
      should.raise(Temple::InvalidExpression){
        os.call([:multi, [:newline], [:static, "foo"], [:foo]])
      }
      
    end
    
  
  end
  
  describe Temple::Filters::OnlyStatic::MaskDynamic do
  
    it "should mask dynamics and should make it possible to recover it" do
    
      os = Temple::Filters::OnlyStatic::MaskDynamic.new
      
      data = [:multi, [:newline], [:static, "foo"], [:foo]]
      
      os.recover( os.call(data) ).should == data
      
    end
    
  end


end
