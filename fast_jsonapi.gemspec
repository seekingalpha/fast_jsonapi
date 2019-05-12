lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "fast_jsonapi/version"

Gem::Specification.new do |gem|
  gem.name                      = "fast_jsonapi"
  gem.version                   = FastJsonapi::VERSION

  gem.required_ruby_version     = '>= 2.0.0' if gem.respond_to? :required_ruby_version=
  gem.required_rubygems_version = Gem::Requirement.new(">= 0") if gem.respond_to? :required_rubygems_version=
  gem.metadata                  = { "allowed_push_host" => "https://rubygems.org" } if gem.respond_to? :metadata=
  gem.require_paths             = ["lib"]
  gem.authors                   = ["Shishir Kakaraddi", "Srinivas Raghunathan", "Adam Gross", "SeekingAlpha: Yoni Gittelman"]
  gem.description               = "JSON API(jsonapi.org) serializer that works with rails and can be used to serialize any kind of ruby objects"
  gem.email                     = ""
  gem.extra_rdoc_files          = %w(LICENSE.txt README.md)
  gem.files                     = Dir["lib/**/*"]
  gem.homepage                  = "http://github.com/Netflix/fast_jsonapi"
  gem.licenses                  = ["Apache-2.0"]
  gem.rubygems_version          = "2.5.1"
  gem.summary                   = "fast JSON API(jsonapi.org) serializer - SA Fork"

  gem.add_runtime_dependency(%q<activesupport>, ["4.2.10"])
  gem.add_development_dependency(%q<activerecord>, ["4.2.10"])

  gem.add_runtime_dependency(%q<lru_redux>, [">= 0"])
  gem.add_runtime_dependency(%q<oj>)

  gem.add_development_dependency(%q<rspec>, ["~> 3.5.0"])
  gem.add_development_dependency(%q<rspec-benchmark>, ["~> 0.3.0"])
  gem.add_development_dependency(%q<bundler>, ["~> 1.0"])
  gem.add_development_dependency(%q<byebug>, [">= 0"])
  gem.add_development_dependency(%q<active_model_serializers>, ["~> 0.10.7"])
  gem.add_development_dependency(%q<sqlite3>, ["1.3.13"])
  gem.add_development_dependency(%q<jsonapi-rb>, ["~> 0.5.0"])
  gem.add_development_dependency(%q<jsonapi-serializers>, ["~> 1.0.0"])
end
