# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "em/posix/spawn/version"

Gem::Specification.new do |s|
  s.name        = "em-posix-spawn"
  s.version     = EventMachine::POSIX::Spawn::VERSION

  s.authors     = ["Pieter Noordhuis"]
  s.email       = ["pcnoordhuis@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{TODO: Write a gem summary}
  s.description = %q{TODO: Write a gem description}

  s.files         = `git ls-files`.split("\n")
  s.require_paths = ["lib"]

  s.add_runtime_dependency "eventmachine"
  s.add_runtime_dependency "posix-spawn"
end
