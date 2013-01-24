# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "nats/rpc/version"

Gem::Specification.new do |s|
  s.name        = "nats-rpc"
  s.version     = NATS::RPC::VERSION
  s.authors     = ["Pieter Noordhuis"]
  s.email       = ["pcnoordhuis@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Thin RPC layer for NATS}
  s.description = s.summary

  s.rubyforge_project = "nats-rpc"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency "nats", "~> 0.4.0"
  s.add_runtime_dependency "json_pure"
end
