source "https://rubygems.org"

gem "rake", "~> 13.0"

# RuboCop 1.92 needs Ruby 2.7+, so older Rubies skip the rubocop task.
gem "rubocop", "~> 1.92.0", :require => false if RUBY_VERSION >= "2.7"

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
  gem "rack-test"
  gem "rspec", "~> 3.2"
  # SimpleCov 1.3 needs Ruby 3.3+, so older Rubies skip coverage.
  if RUBY_VERSION >= "3.3"
    gem "simplecov", "~> 1.3", :require => false
    gem "simplecov-lcov", :require => false
  end
  gem "webmock", "~> 3.0"
end

# Specify your gem's dependencies in omniauth-oauth2.gemspec
gemspec
