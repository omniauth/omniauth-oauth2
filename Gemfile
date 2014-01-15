source 'http://rubygems.org'

gem 'rake'

group :development do
  gem 'guard'
  gem 'guard-rspec'
  gem 'guard-bundler'
end

group :test do
  gem 'rack-test'
  gem 'rspec', '~> 2.14'
  gem 'simplecov'
  gem 'webmock'
end

platforms :rbx do
 gem 'rubysl', '~> 2.0'
 gem 'rubinius-developer_tools'
end

# Specify your gem's dependencies in omniauth-oauth2.gemspec
gemspec
