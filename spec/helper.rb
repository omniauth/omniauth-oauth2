$LOAD_PATH.unshift File.expand_path("..", __FILE__)
$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

# Coverage is measured on CRuby 3.3+ only. SimpleCov 1.3 needs Ruby 3.3,
# and JRuby and TruffleRuby count lines differently.
if RUBY_ENGINE == "ruby" && Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.3")
  require "simplecov"
  require "simplecov-lcov"

  SimpleCov::Formatter::LcovFormatter.config.report_with_single_file = true

  SimpleCov.formatters = [
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::LcovFormatter,
  ]

  SimpleCov.start "strict"
end

require "rspec"
require "rack/test"
require "webmock/rspec"
require "omniauth"
require "omniauth-oauth2"

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  config.extend OmniAuth::Test::StrategyMacros, :type => :strategy
  config.include Rack::Test::Methods
  config.include WebMock::API
end
