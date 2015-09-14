require 'spec_helper'

describe UrlFetcher do

  it "should fetch a URL to a temp file" do
    WebMock.stub_request(:get, "http://example.com/test").to_return(:status => 200, :body => "Hello", :headers => {"Content-Length" => 5})
    url_fetcher = UrlFetcher.new("http://example.com/test")
    expect(url_fetcher).to be_success
    expect(url_fetcher).not_to be_redirect
    expect(url_fetcher.header("content-length")).to eql("5")
    expect(url_fetcher).to_not be_closed
    expect(url_fetcher.body).to_not be_closed
    expect(url_fetcher.body.read).to eql("Hello")
    url_fetcher.close
    expect(url_fetcher).to be_closed
    expect(url_fetcher.body).to be_closed
  end

  it "should perform a POST request" do
    WebMock.stub_request(:post, "http://example.com/test").to_return(:status => 200, :body => "Hello", :headers => {"Content-Length" => 5})
    url_fetcher = UrlFetcher.new("http://example.com/test", :method => :post)
    expect(url_fetcher).to be_success
    expect(url_fetcher).not_to be_redirect
    expect(url_fetcher.header("content-length")).to eql("5")
    expect(url_fetcher.body.read).to eql("Hello")
  end

  it "should perform a HEAD request" do
    WebMock.stub_request(:head, "http://example.com/test").to_return(:status => 200, :body => nil, :headers => {"Content-Length" => 5})
    url_fetcher = UrlFetcher.new("http://example.com/test", :method => :head)
    expect(url_fetcher).to be_success
    expect(url_fetcher).not_to be_redirect
    expect(url_fetcher.header("content-length")).to eql("5")
    expect(url_fetcher.body).to be_nil
  end

  it "should work with SSL" do
    WebMock.stub_request(:get, "https://example.com/test").to_return(:status => 200, :body => "Hello", :headers => {"Content-Length" => 5})
    url_fetcher = UrlFetcher.new("https://example.com/test")
    expect(url_fetcher).to be_success
    expect(url_fetcher).not_to be_redirect
    expect(url_fetcher.header("content-length")).to eql("5")
    expect(url_fetcher.body.read).to eql("Hello")
  end

  it "should honor redirects" do
    WebMock.stub_request(:get, "http://example.com/test1").to_return(:status => 301, :headers => {"Location" => "http://example.com/test2"})
    WebMock.stub_request(:get, "http://example.com/test2").to_return(:status => 200, :body => "Hello", :headers => {"Content-Length" => 5})
    url_fetcher = UrlFetcher.new("http://example.com/test1")

    expect(url_fetcher).to be_success
    expect(url_fetcher).not_to be_redirect
    expect(url_fetcher.header("content-length")).to eql("5")
    expect(url_fetcher.body.read).to eql("Hello")
  end

  it "should not honor redirects if :follow_redirects == false" do
    WebMock.stub_request(:get, "http://example.com/test1").to_return(:status => 301, :headers => {"Location" => "http://example.com/test2"})
    url_fetcher = UrlFetcher.new("http://example.com/test1", :follow_redirects => false)

    expect(url_fetcher).not_to be_success
    expect(url_fetcher).to be_redirect
  end

  it "should call a block before each redirect with the new location" do
    WebMock.stub_request(:get, "http://example.com/test1").to_return(:status => 302, :headers => {"Location" => "http://example.com/test2"})
    WebMock.stub_request(:get, "http://example.com/test2").to_return(:status => 302, :headers => {"Location" => "http://example.com/test3"})
    WebMock.stub_request(:get, "http://example.com/test3").to_return(:status => 200, :body => "Hello", :headers => {"Content-Length" => 5})
    redirects = []
    url_fetcher = UrlFetcher.new("http://example.com/test1") do |location|
      redirects << location
    end

    expect(url_fetcher).to be_success
    expect(url_fetcher).not_to be_redirect
    expect(url_fetcher.header("content-length")).to eql("5")
    expect(url_fetcher.body.read).to eql("Hello")
    expect(redirects).to eql(["http://example.com/test2", "http://example.com/test3"])
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

    expect(url_fetcher).not_to be_success
    expect(url_fetcher).to be_redirect
    expect(url_fetcher.body).to be_nil
    expect(redirects).to eql(["http://example.com/test2"])
  end

  it "should raise an error if there is a circular redirect" do
    WebMock.stub_request(:get, "http://example.com/test").to_return(:status => 302, :headers => {"Location" => "http://example.com/test"})
    expect{ UrlFetcher.new("http://example.com/test") }.to raise_error(UrlFetcher::CircularRedirect)
  end

  it "should raise an error if there are too many redirects" do
    6.times do |i|
      WebMock.stub_request(:get, "http://example.com/test#{i}").to_return(:status => 302, :headers => {"Location" => "http://example.com/test#{i + 1}"})
    end
    expect{ UrlFetcher.new("http://example.com/test0") }.to raise_error(UrlFetcher::TooManyRedirects)
  end

  it "should raise an error if an HTTP error is returned" do
    WebMock.stub_request(:get, "http://example.com/test").to_return(:status => 404, :body => "Not Found")
    expect{ UrlFetcher.new("http://example.com/test") }.to raise_error(Net::HTTPServerException)
  end

  it "should not unlink the temp file if asked not to" do
    WebMock.stub_request(:get, "http://example.com/test").to_return(:status => 200, :body => "Hello", :headers => {"Content-Length" => 5})
    url_fetcher = UrlFetcher.new("http://example.com/test", :unlink => false)

    expect(url_fetcher).to be_success
    expect(url_fetcher).not_to be_redirect
    expect(url_fetcher.header("content-length")).to eql("5")
    expect(url_fetcher.body).to_not be_closed
    expect(url_fetcher.body.read).to eql("Hello")
    expect(url_fetcher.body.path).not_to be_nil
  end

  it "should limit the size of the file downloaded" do
    WebMock.stub_request(:get, "http://example.com/test").to_return(:status => 200, :body => "Hello", :headers => {"Content-Length" => 1001})
    expect do
      UrlFetcher.new("http://example.com/test", :max_size => 1000)
    end.to raise_error(UrlFetcher::FileTooBig)
  end
end
