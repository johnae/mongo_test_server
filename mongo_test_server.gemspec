# -*- encoding: utf-8 -*-
require File.expand_path('../lib/mongo_test_server/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["John Axel Eriksson"]
  gem.email         = ["john@insane.se"]
  gem.description   = %q{Standalone mongo test server for use with rspec or other unit testing framework}
  gem.summary       = %q{Standalone mongo test server for use with rspec or other unit testing framework}
  gem.homepage      = ""

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "mongo_test_server"
  gem.require_paths = ["lib"]
  gem.version       = MongoTestServer::VERSION

  gem.add_dependency('mongo', '>=1.6.0')
  unless RUBY_PLATFORM == 'java'
    gem.add_development_dependency('bson_ext', '>=1.3.0')
  end

end