source "https://rubygems.org"

gem "rake", "~> 13.0"

# Steep 2.1 needs Ruby 3.3+, so older Rubies skip the steep task. It checks
# against the types omniauth ships from 2.2.0 on, so use omniauth's master
# branch until 2.2.0 is released.
if RUBY_VERSION >= "3.3"
  gem "omniauth", :git => "https://github.com/omniauth/omniauth.git"
  gem "steep", "~> 2.1", :require => false, :platforms => :mri
end

# Mutant needs Ruby 3.3+, so older Rubies skip the mutant task.
if RUBY_VERSION >= "3.3"
  gem "mutant", "~> 0.17.1", :platforms => :mri
  gem "mutant-rspec", "~> 0.17.1", :require => false, :platforms => :mri
end

group :test do
  gem "addressable", "~> 2.3.8", :platforms => %i[jruby ruby_18]
  gem "json", :platforms => %i[jruby ruby_18 ruby_19]
  gem "mime-types", "~> 1.25", :platforms => %i[jruby ruby_18]
  gem "rack-test"
  gem "rest-client", "~> 1.8.0", :platforms => %i[jruby ruby_18]
  gem "rspec", "~> 3.2"
  gem "rubocop", ">= 0.51", :platforms => %i[ruby_19 ruby_20 ruby_21 ruby_22 ruby_23 ruby_24]
  # SimpleCov 1.3 needs Ruby 3.3+, so older Rubies skip coverage.
  if RUBY_VERSION >= "3.3"
    gem "simplecov", "~> 1.3", :require => false
    gem "simplecov-lcov", :require => false
  end
  gem 'tins', '~> 1.13', :platforms => %i[jruby_18 jruby_19 ruby_19]
  gem "webmock", "~> 3.0"
end

# Specify your gem's dependencies in omniauth-oauth2.gemspec
gemspec
