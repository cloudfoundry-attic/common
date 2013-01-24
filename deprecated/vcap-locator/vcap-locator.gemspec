# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "vcap/locator/version"

Gem::Specification.new do |s|
  s.name        = "vcap-locator"
  s.version     = VCAP::Locator::VERSION
  s.authors     = ["Pieter Noordhuis"]
  s.email       = ["pcnoordhuis@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Service locator on top of NATS-RPC}
  s.description = s.summary

  s.rubyforge_project = "nats-rpc"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
