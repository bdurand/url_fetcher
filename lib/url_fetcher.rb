require "url_fetcher/version"

# This class will fetch the contents of a URL and store them in a Tempfile. The
# results are exposed as a stream. This class is not thread safe.
module UrlFetcher
  class Base
    attr_reader :url

    # Pass in a block that will be called with the new URL on a redirect to hook into
    # the redirect logic. If this block returns false then the redirect will not be called.
    def initialize(url, options = {}, &redirect_hook)
      @url = url
      @redirect_hook = redirect_hook
      options = options.reverse_merge(:unlink => true, :follow_redirects => true, :method => :get)
      @response = fetch_response(@url, options)
    end

    # Return an open stream to the downloaded URL.
    def body
      @response.body if success?
    end

    # Get the header with the specified name from the response.
    def header(name)
      @response[name]
    end

    # Return true if the response was a redirect (i.e. the redirect_block passed in the header returned false on a redirect)
    def redirect?
      @response.is_a? Net::HTTPRedirection
    end

    # Return true of the the response was a success.
    def success?
      @response.is_a? Net::HTTPSuccess
    end

    private

    def fetch_response(url, options, previous_attempts = [])
      raise "Too many redirects" if previous_attempts.size > 5
      raise "Circular redirect" if previous_attempts.include?(url)
      previous_attempts << url

      uri = URI(url)

      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = options[:read_timeout] || 20 # This is seconds. Default is 60.
      http.open_timeout = options[:open_timeout] || 10
      if uri.scheme == "https"
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      request = case options[:method]
      when :head
        Net::HTTP::Head.new(uri.request_uri)
      when :post
        Net::HTTP::Post.new(uri.request_uri)
      else
        Net::HTTP::Get.new(uri.request_uri)
      end

      response = http.request(request) do |resp|
        unless resp.is_a?(Net::HTTPSuccess) || resp.is_a?(Net::HTTPRedirection)
          resp.value # Raises an appropriate HTTP error
        end
        if resp.is_a?(Net::HTTPSuccess) && resp.class.body_permitted?
          content_length = resp["Content-Length"].to_i
          raise "File to big (#{content_length} bytes" if content_length > (options[:max_size] || 10.megabytes)
          tempfile = Tempfile.new("url_fetcher", :encoding => 'ascii-8bit')
          resp.read_body(tempfile)
          tempfile.close
        end
      end

      if response.is_a?(Net::HTTPRedirection) && options[:follow_redirects]
        location = response["Location"]
        unless location.include?(':')
          location = Addressable::URI.parse(location)
          location.scheme = uri.scheme
          location.host = uri.host
        end
        abort_redirect = (@redirect_hook ? @redirect_hook.call(location.to_s) == false : false)
        response = fetch_response(location, options, previous_attempts) unless abort_redirect
      end

      response
    end
  end
end
