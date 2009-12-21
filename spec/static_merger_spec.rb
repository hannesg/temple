require File.dirname(__FILE__) + '/spec_helper.rb'

describe_filter :StaticMerger do
  it "should merge several statics" do
    @filter.compile([:lines,
      [[:static, "Hello "],
       [:static, "World, "],
       [:static, "Good night"]]
    ]).should == [:lines,
      [[:static, "Hello World, Good night"]]
    ]
  end
  
  it "should merge several statics around block" do
    @filter.compile([:lines,
      [[:static, "Hello "],
       [:static, "World!"],
       [:block, "123"],
       [:static, "Good night, "],
       [:static, "everybody"]]
    ]).should == [:lines,
      [[:static, "Hello World!"],
       [:block, "123"],
       [:static, "Good night, everybody"]]
    ]
  end
  
  it "should merge several statics across lines" do
    @filter.compile([:lines,
      [[:static, "Hello "]],
      [[:static, "World!"], [:block, "123"]],
      [[:block, "456"], [:static, "Good "]],
      [[:static, "night, "], [:static, "everybody"]]
    ]).should == [:lines,
      [[:static, "Hello World!"]],
      [[:block, "123"]],
      [[:block, "456"], [:static, "Good night, everybody"]],
      []
    ]
  end
end
