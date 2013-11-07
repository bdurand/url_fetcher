require 'spec_helper'

describe UrlFetcher do

  it "should fetch a URL to a temp file" do
    WebMock.stub_request(:get, "http://example.com/test").to_return(:status => 200, :body => "Hello", :headers => {"Content-Length" => 5})
    url_fetcher = UrlFetcher.new("http://example.com/test")
    url_fetcher.success?.should == true
    url_fetcher.redirect?.should == false
    url_fetcher.header("content-length").should == "5"
    url_fetcher.body.open
    url_fetcher.body.read.should == "Hello"
  end

  it "should perform a POST request" do
    WebMock.stub_request(:post, "http://example.com/test").to_return(:status => 200, :body => "Hello", :headers => {"Content-Length" => 5})
    url_fetcher = UrlFetcher.new("http://example.com/test", :method => :post)
    url_fetcher.success?.should == true
    url_fetcher.redirect?.should == false
    url_fetcher.header("content-length").should == "5"
    url_fetcher.body.open
    url_fetcher.body.read.should == "Hello"
  end

  it "should perform a HEAD request" do
    WebMock.stub_request(:head, "http://example.com/test").to_return(:status => 200, :body => nil, :headers => {"Content-Length" => 5})
    url_fetcher = UrlFetcher.new("http://example.com/test", :method => :head)
    url_fetcher.success?.should == true
    url_fetcher.redirect?.should == false
    url_fetcher.header("content-length").should == "5"
    url_fetcher.body.should == nil
  end

  it "should work with SSL" do
    WebMock.stub_request(:get, "https://example.com/test").to_return(:status => 200, :body => "Hello", :headers => {"Content-Length" => 5})
    url_fetcher = UrlFetcher.new("https://example.com/test")
    url_fetcher.success?.should == true
    url_fetcher.redirect?.should == false
    url_fetcher.header("content-length").should == "5"
    url_fetcher.body.open.read.should == "Hello"
  end

  it "should honor redirects" do
    WebMock.stub_request(:get, "http://example.com/test1").to_return(:status => 301, :headers => {"Location" => "http://example.com/test2"})
    WebMock.stub_request(:get, "http://example.com/test2").to_return(:status => 200, :body => "Hello", :headers => {"Content-Length" => 5})
    url_fetcher = UrlFetcher.new("http://example.com/test1")
    url_fetcher.success?.should == true
    url_fetcher.redirect?.should == false
    url_fetcher.header("content-length").should == "5"
    url_fetcher.body.open.read.should == "Hello"
  end

  it "should not honor redirects if :follow_redirects == false" do
    WebMock.stub_request(:get, "http://example.com/test1").to_return(:status => 301, :headers => {"Location" => "http://example.com/test2"})
    url_fetcher = UrlFetcher.new("http://example.com/test1", :follow_redirects => false)
    url_fetcher.success?.should == false
    url_fetcher.redirect?.should == true
  end

  it "should call a block before each redirect with the new location" do
    WebMock.stub_request(:get, "http://example.com/test1").to_return(:status => 302, :headers => {"Location" => "http://example.com/test2"})
    WebMock.stub_request(:get, "http://example.com/test2").to_return(:status => 302, :headers => {"Location" => "http://example.com/test3"})
    WebMock.stub_request(:get, "http://example.com/test3").to_return(:status => 200, :body => "Hello", :headers => {"Content-Length" => 5})
    redirects = []
    url_fetcher = UrlFetcher.new("http://example.com/test1") do |location|
      redirects << location
    end
    url_fetcher.success?.should == true
    url_fetcher.body.open
    url_fetcher.body.read.should == "Hello"
    redirects.should == ["http://example.com/test2", "http://example.com/test3"]
  end

  it "should abort redirecting if a block is given that returns false" do
    WebMock.stub_request(:get, "http://example.com/test1").to_return(:status => 302, :headers => {"Location" => "http://example.com/test2"})
    WebMock.stub_request(:get, "http://example.com/test2").to_return(:status => 302, :headers => {"Location" => "http://example.com/test3"})
    WebMock.stub_request(:get, "http://example.com/test3").to_return(:status => 200, :body => "Hello", :headers => {"Content-Length" => 5})
    redirects = []
    url_fetcher = UrlFetcher.new("http://example.com/test1") do |location|
      redirects << location
      false
    end
    url_fetcher.success?.should == false
    url_fetcher.redirect?.should == true
    url_fetcher.body.should == nil
    redirects.should == ["http://example.com/test2"]
  end

  it "should raise an error if there is a circular redirect" do
    WebMock.stub_request(:get, "http://example.com/test").to_return(:status => 302, :headers => {"Location" => "http://example.com/test"})
    lambda{ UrlFetcher.new("http://example.com/test") }.should raise_error(UrlFetcher::CircularRedirect)
  end

  it "should raise an error if there are too many redirects" do
    6.times do |i|
      WebMock.stub_request(:get, "http://example.com/test#{i}").to_return(:status => 302, :headers => {"Location" => "http://example.com/test#{i + 1}"})
    end
    lambda{ UrlFetcher.new("http://example.com/test0") }.should raise_error(UrlFetcher::TooManyRedirects)
  end

  it "should raise an error if an HTTP error is returned" do
    WebMock.stub_request(:get, "http://example.com/test").to_return(:status => 404, :body => "Not Found")
    lambda{ UrlFetcher.new("http://example.com/test") }.should raise_error(Net::HTTPServerException)
  end

  it "should not unlink the temp file if asked not to" do
    WebMock.stub_request(:get, "http://example.com/test").to_return(:status => 200, :body => "Hello", :headers => {"Content-Length" => 5})
    url_fetcher = UrlFetcher.new("http://example.com/test", :unlink => false)
    url_fetcher.success?.should == true
    url_fetcher.body.open.read.should == "Hello"
    url_fetcher.body.path.should_not == nil
  end

  it "should limit the size of the file downloaded" do
    WebMock.stub_request(:get, "http://example.com/test").to_return(:status => 200, :body => "Hello", :headers => {"Content-Length" => 1001})
    lambda do
      UrlFetcher.new("http://example.com/test", :max_size => 1000)
    end.should raise_error
  end
end
