source 'http://rubygems.org'

gem 'rake'

group :development do
  platforms :ruby_19, :ruby_20, :ruby_21 do
    gem 'guard'
    gem 'guard-rspec'
    gem 'guard-bundler'
  end
end

group :test do
  gem 'coveralls', :require => false
  gem 'json', :platforms => [:jruby, :ruby_18, :ruby_19]
  gem 'mime-types', '~> 1.25', :platforms => [:jruby, :ruby_18]
  gem 'rack-test'
  gem 'rspec', '~> 3.0.0'
  gem 'rubocop', '>= 0.21', :platforms => [:ruby_19, :ruby_20, :ruby_21]
  gem 'simplecov', :require => false
  gem 'webmock'
end

# Specify your gem's dependencies in omniauth-oauth2.gemspec
gemspec
