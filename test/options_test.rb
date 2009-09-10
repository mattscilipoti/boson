require File.join(File.dirname(__FILE__), 'test_helper')
require "boson/options"

module Boson
  class OptionsTest < Test::Unit::TestCase
  def create(opts)
    @opt = Boson::Options.new(opts)
  end
  
  def parse(*args)
    @non_opts = []
    @opt.parse(args.flatten)
  end
  
  context "naming" do
    it "automatically aliases long switches with their first letter" do
      create "--foo" => true
      parse("-f")["foo"].should == true
    end
    
    it "doesn't auto-alias switches that have multiple names given" do
      create ["--foo", "--bar"] => :boolean
      parse("-f")["foo"].should == nil
    end
    
    it "allows multiple aliases for a given switch" do
      create ["--foo", "--bar", "--baz"] => :optional
      parse("--foo", "12")["foo"].should == "12"
      parse("--bar", "12")["foo"].should == "12"
      parse("--baz", "12")["foo"].should == "12"
    end
    
    it "allows custom short names" do
      create "-f" => :optional
      parse("-f", "12").should == {"f" => "12"}
    end
    
    it "allows custom short-name aliases" do
      create ["--bar", "-f"] => :optional
      parse("-f", "12").should == {"bar" => "12"}
    end
    
    it "should allows humanized switch input" do
      create 'foo' => :optional, :bar => :required
      parse("-f", "1", "-b", "2").should == {"foo" => "1", "bar" => "2"}
    end
    
    it "doesn't recognize long switch format for a switch that is originally short" do
      create 'f' => :optional
      parse("-f", "1").should == {"f" => "1"}
      parse("--f", "1").should == {}
    end
    
    it "accepts --[no-]opt variant for booleans, setting false for value" do
      create "--foo" => false
      parse("--foo")["foo"].should == true
      parse("--no-foo")["foo"].should == false
    end
    
    it "will prefer 'no-opt' variant over inverting 'opt' if explicitly set" do
      create "--no-foo" => true
      parse("--no-foo")["no-foo"].should == true
    end
    
  end
  
  it "accepts a switch=<value> assignment" do
    create "--foo" => :required
    parse("--foo=12")["foo"].should == "12"
    parse("-f=12")["foo"].should == "12"
    parse("--foo=bar=baz")["foo"].should == "bar=baz"
    parse("--foo=sentence with spaces")["foo"].should == "sentence with spaces"
  end
  
  it "accepts a -nXY assignment" do
    create "--num" => :required
    parse("-n12")["num"].should == "12"
  end
  
  it "accepts conjoined short switches" do
    create "--foo" => true, "--bar" => true, "--app" => true
    opts = parse "-fba"
    opts["foo"].should == true
    opts["bar"].should == true
    opts["app"].should == true
  end
  
  it "accepts conjoined short switches with argument" do
    create "--foo" => true, "--bar" => true, "--app" => :required
    opts = parse "-fba", "12"
    opts["foo"].should == true
    opts["bar"].should == true
    opts["app"].should == "12"
  end
  
  it "makes hash keys available as symbols as well" do
    create "--foo" => :optional
    parse("--foo", "12")[:foo].should == "12"
  end
  
  it "result is immutable" do
    create "--foo" => :optional
    assert_raises(TypeError) {
      hash = parse
      hash['foo'] = 'baz'
    }
  end
  
  context "with no arguments" do
    it "and no switches returns an empty hash" do
      create({})
      parse.should == {}
    end
  
    it "and several switches returns an empty hash" do
      create "--foo" => :boolean, "--bar" => :optional
      parse.should == {}
    end
  
    it "and a required switch raises an error" do
      create "--foo" => :required
      assert_raises(Boson::Options::Error, "no value provided for required argument '--foo'") { parse }
    end
  end
  
  it "doesn't set nonexistant switches" do
    create "--foo" => :boolean
    parse("--foo")["bar"].should == nil
    opts = parse
    opts["foo"].should == nil
  end
  
  context " with several optional switches" do
    before :each do
      create "--foo" => :optional, "--bar" => :optional
    end
  
    it "sets switches without arguments to true" do
      parse("--foo")["foo"].should == true
      parse("--bar")["bar"].should == true
    end
  
    it "doesn't set nonexistant switches" do
      parse("--foo")["bar"].should == nil
      parse("--bar")["foo"].should == nil
    end
  
    it "sets switches with arguments to their arguments" do
      parse("--foo", "12")["foo"].should == "12"
      parse("--bar", "12")["bar"].should == "12"
    end
  
    it "assumes something that could be either a switch or an argument is a switch" do
      parse("--foo", "--bar")["foo"].should == true
    end
  
    it "overwrites earlier values with later values" do
      parse("--foo", "--foo", "12")["foo"].should == "12"
      parse("--foo", "12", "--foo", "13")["foo"].should == "13"
    end
  end
  
  context " with one required and one optional switch" do
    before :each do
      create "--foo" => :required, "--bar" => :optional
    end
  
    it "raises an error if the required switch has no argument" do
      assert_raises(Boson::Options::Error) { parse("--foo") }
    end
  
    it "raises an error if the required switch isn't given" do
      assert_raises(Boson::Options::Error) { parse("--bar") }
    end
  
    it "raises an error if a switch name is given as the argument to the required switch" do
	  assert_raises(Boson::Options::Error, "cannot pass switch '--bar' as an argument") { parse("--foo", "--bar") }
    end
  end
  
  it "extracts non-option arguments" do
    create "--foo" => :required, "--bar" => true
    parse("foo", "bar", "--baz", "--foo", "12", "--bar", "-T", "bang").should == {
      "foo" => "12", "bar" => true
    }
    @opt.leading_non_opts.should == ["foo", "bar", "--baz"]
    @opt.trailing_non_opts.should == ["-T", "bang"]
    @opt.non_opts.should == ["foo", "bar", "--baz", "-T", "bang"]
  end
  
  context "optional arguments with default values" do
    before(:each) do
      create "--branch" => "master"
    end
    
    it "should get the specified value" do
      parse("--branch", "bugfix").should == { "branch" => "bugfix" }
    end
  
    it "should get the default value when not specified" do
      parse.should == { "branch" => "master" }
    end
  end
  
  context 'Hash' do
    before(:each) do
      @hash = Boson::Options::Hash.new 'foo' => 'bar', 'baz' => 'bee', 'force' => true
    end
    
    it "has values accessible by either strings or symbols" do
      @hash['foo'].should == 'bar'
      @hash[:foo].should  == 'bar'
      @hash.values_at(:foo, :baz).should == ['bar', 'bee']
    end
    
    it "should handles magic boolean predicates" do
      @hash.force?.should == true
      @hash.foo?.should == true
      @hash.nothing?.should == false
    end
    
    it "should map methods to keys: hash.foo => hash[:foo]" do
      @hash.foo.should == @hash['foo']
    end
    
    it "should map setters to keys: hash.foo=bar => hash[:foo] => bar" do
      @hash.foo = :bar2
      @hash.foo.should == :bar2
    end
    
  end
  
  context ":numeric type" do
    before(:each) do
      create "n" => :numeric, "m" => 5
    end
    
    it "supports numeric defaults" do
      parse["m"].should == 5
    end
    
    it "converts values to numeric types" do
      parse("-n", "3", "-m", ".5").should == {"n" => 3, "m" => 0.5}
    end
    
    it "raises error when value isn't numeric" do
	  assert_raises(Boson::Options::Error, "expected numeric value for '-n'; got \"foo\"") { parse("-n", "foo") }
    end
    
    it "raises error when switch is present without value" do
	  assert_raises(Boson::Options::Error, "no value provided for argument '-n'") { parse("-n") }
    end
  end
  
  context "#formatted_usage" do
    def usage
      @opt.formatted_usage.split(" ").sort
    end
    
    it "outputs optional args with sample values" do
      create "--repo" => :optional, "--branch" => "bugfix", "-n" => 6
      usage.should == %w([--branch=bugfix] [--repo=REPO] [-n=6])
    end
    
    it "outputs numeric args with 'N' as sample value" do
      create "--iter" => :numeric
      usage.should == ["[--iter=N]"]
    end
  end
end
end