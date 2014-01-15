source 'http://rubygems.org'

gem 'rake'

group :development do
  gem 'guard'
  gem 'guard-rspec'
  gem 'guard-bundler'
end

group :test do
  gem 'coveralls', :require => false
  gem 'rack-test'
  gem 'rspec', '~> 2.14'
  gem 'rubocop', '>= 0.16', :platforms => [:ruby_19, :ruby_20, :ruby_21]
  gem 'simplecov', :require => false
  gem 'webmock'
end

platforms :rbx do
  gem 'racc'
  gem 'rubysl', '~> 2.0'
  gem 'rubinius-developer_tools'
end

# Specify your gem's dependencies in omniauth-oauth2.gemspec
gemspec
