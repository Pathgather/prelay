# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'prelay/version'

Gem::Specification.new do |spec|
  spec.name          = 'prelay'
  spec.version       = Prelay::VERSION
  spec.authors       = ["Chris Hanks"]
  spec.email         = ['christopher.m.hanks@gmail.com']

  spec.summary       = %q{Service GraphQL/Relay queries in a composable fashion.}
  spec.description   = %q{Tooling for servicing GraphQL/Relay queries in a composable fashion.}
  spec.homepage      = "TODO: Put your gem's website or public repo URL here."
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'sequel',        '~> 4.29'
  spec.add_dependency 'graphql',       '~> 0.10.7'
  spec.add_dependency 'graphql-relay', '~> 0.6.1'

  spec.add_development_dependency 'bundler',        '~> 1.11'
  spec.add_development_dependency 'rake',           '~> 10.0'
  spec.add_development_dependency 'minitest',       '~> 5.0'
  spec.add_development_dependency 'minitest-hooks', '~> 1.4'
end
