$:.push File.expand_path("../lib", __FILE__)
require "vcap/logging/version"

Gem::Specification.new do |s|
  s.name        = "vcap_logging"
  s.version     = VCAP::Logging::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["mpage"]
  s.email       = ["mpage@vmware.com"]
  s.homepage    = "http://www.cloudfoundry.com"
  s.summary     = %q{Minimal logging gem used for CF components}
  s.description = %q{This provides a minimal logging gem to be used across CF components}

  s.files         = %w(Rakefile Gemfile) + Dir.glob("{lib,spec}/**/*")
  s.require_paths = ["lib"]

  s.add_dependency 'rake'
  s.add_development_dependency 'rspec'
end
