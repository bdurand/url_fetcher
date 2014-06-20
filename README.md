# UrlFetcher

This gem provides a class that will fetch a URL response and save the body to a Tempfile. This can be useful if you are fetching large HTTP objects so you don't need to read them into memory all at once. The response body is exposed as a stream.

## Installation

Add this line to your application's Gemfile:

    gem 'url_fetcher'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install url_fetcher

## Usage

response = UrlFetcher.new("http://example.com/large_file")
response.body # Returns a stream to a the body from a Tempfile on disk.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
