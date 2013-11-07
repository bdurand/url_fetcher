class UrlFetcher

  class Error < StandardError ; end

  class TooManyRedirects < Error
    attr_reader :url, :max_attempts
    def initialize(url, max_attempts)
      @url, @max_attempts = url, max_attempts
    end

    def to_s
      "#{url} has too many redirects (over #{max_attempts})."
    end
  end


  class CircularRedirect < Error
    attr_reader :url

    def initialize(url)
      @url = url
    end

    def to_s
      "#{url} has a redirect loop."
    end
  end
end
