$:.push File.expand_path("../lib", __FILE__)
require "netlink/version"

Gem::Specification.new do |s|
  s.name        = "netlink"
  s.version     = Netlink::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["mpage"]
  s.email       = ["mpage@vmware.com"]
  s.homepage    = ""
  s.summary     = %q{TODO: Write a gem summary}
  s.description = %q{TODO: Write a gem description}

  s.rubyforge_project = "netlink"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency 'bindata'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rake'
end
