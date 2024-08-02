lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "omniauth-oauth2/version"

Gem::Specification.new do |gem|
  gem.add_dependency "oauth2", [">= 2.0.2", "< 3"]
  gem.add_dependency "omniauth", "~> 2.0"

  gem.authors       = ["Erik Berlin", "Michael Bleigh", "Tom Milewski"]
  gem.email         = ["sferik@gmail.com", "michael@intridea.com", "tmilewski@gmail.com"]
  gem.description   = "An abstract OAuth2 strategy for OmniAuth."
  gem.summary       = gem.description
  gem.homepage      = "https://github.com/omniauth/omniauth-oauth2"
  gem.licenses      = %w[MIT]

  gem.executables   = `git ls-files -- bin/*`.split("\n").collect { |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n").grep_v(%r{spec/})
  gem.name          = "omniauth-oauth2"
  gem.require_paths = %w[lib]
  gem.version       = OmniAuth::OAuth2::VERSION
  gem.metadata["rubygems_mfa_required"] = "true"
end
