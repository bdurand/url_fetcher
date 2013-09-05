# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'url_fetcher/version'

Gem::Specification.new do |spec|
  spec.name          = "url_fetcher"
  spec.version       = UrlFetcher::VERSION
  spec.authors       = ["weheartit"]
  spec.email         = ["dev@weheartit.com"]
  spec.description   = %q{Fetch resources from the internetz!}
  spec.summary       = %q{Fetch resources from the internetz with circular redirects support}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency('addressable', '~>2.3.4')

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "webmock"
end
