# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "unsw/version"

Gem::Specification.new do |s|
  s.name        = "unsw"
  s.version     = UNSW::VERSION
  s.authors     = ["UNSW CSESoc"]
  s.email       = ["csesoc.sysadmin.head@cse.unsw.edu.au"]
  s.homepage    = "https://github.com/UNSW-CSESoc/UNSW-Tools"
  s.summary     = "Utilities for UNSW students."
  s.description = "Some helpful utilities for UNSW students. Not affiliated with the University of New South Wales."

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  
  s.add_dependency "nokogiri"
  s.add_development_dependency "rspec"
  
end
