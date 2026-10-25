# Shared setup for the benchmarks: a strategy like the ones built on this
# gem, in a Rack stack with an app behind it, and the token endpoint
# stubbed so that no request leaves the process.

require "faraday"
require "json"
require "logger"
require "rack"
require "rack/mock"
require "securerandom"

# Pin OmniAuth's global configuration, so that no benchmark sees what
# another left behind. OmniAuth logs every phase, to stdout by default.
OmniAuth.config.logger = Logger.new(File::NULL, :level => Logger::FATAL)
OmniAuth.config.test_mode = false
OmniAuth.config.allowed_request_methods = %i[post]
# The request phase's CSRF check is OmniAuth's own, not this gem's.
OmniAuth.config.request_validation_phase = nil
OmniAuth.config.full_host = "https://app.example.com"

module DuelHelper
  # Random state and PKCE verifiers, from a seeded generator instead of
  # the system's, so that every sample makes the same strings. Every
  # SecureRandom method gets its bytes from gen_random.
  module SeededRandom
    class << self
      attr_reader :random

      # Starts the sequence again.
      def reseed
        @random = Random.new(42)
      end
    end

    def gen_random(size)
      SeededRandom.random.bytes(size)
    end
  end

  # A strategy like the ones built on this gem, with a uid and info from
  # the token response, as many providers send them.
  class Strategy < OmniAuth::Strategies::OAuth2
    option :name, "example"

    uid { access_token.params["user_id"] }
    info { {"email" => access_token.params["email"]} }
  end
end
DuelHelper::SeededRandom.reseed
SecureRandom.singleton_class.prepend(DuelHelper::SeededRandom)

TOKEN_RESPONSE = JSON.generate(
  "access_token" => "2YotnFZFEjr1zCsicMWpAA",
  "token_type" => "Bearer",
  "expires_in" => 3600,
  "refresh_token" => "tGzv3JOkF0XG5Qx2TlKWIA",
  "scope" => "openid email",
  "user_id" => "1234567890",
  "email" => "user@example.com",
)

CLIENT_SITE = "https://provider.example.com".freeze
REDIRECT_URI = "https://app.example.com/auth/example/callback".freeze

# The token endpoint, answered in process by Faraday's test adapter.
TOKEN_STUBS = Faraday::Adapter::Test::Stubs.new do |stub|
  stub.post("/oauth/token") do
    [200, {"Content-Type" => "application/json"}, TOKEN_RESPONSE]
  end
end

# The Rack stack: the strategy in front of an app.
def build_app(**options)
  inner = ->(_env) { [200, {"content-type" => "text/plain"}, ["OK"]] }
  DuelHelper::Strategy.new(
    inner,
    "client-id",
    "client-secret",
    :scope => "openid email",
    :client_options => {
      :site => CLIENT_SITE,
      :authorize_url => "/oauth/authorize",
      :token_url => "/oauth/token",
      :connection_build => ->(builder) { builder.adapter(:test, TOKEN_STUBS) },
    },
    **options,
  )
end

# The states that the request phase made, in order, from the seeded
# generator, to send back to the callback.
def states(count)
  DuelHelper::SeededRandom.reseed
  Array.new(count) { SecureRandom.hex(24) }
end

# A session as the request phase left it, with the sign-ins of the given
# states in progress.
def session_with_sign_ins(states, pkce: false)
  oauth2 = {}
  sign_ins = {}
  states.each_with_index do |state, i|
    sign_in = {"redirect_uri" => REDIRECT_URI}
    sign_in["pkce_verifier"] = format("%0128x", i) if pkce
    oauth2[state] = sign_in
    sign_ins[state] = {"origin" => "https://app.example.com/dashboard", "params" => {}}
  end
  {"omniauth.oauth2" => oauth2, "omniauth.sign_ins" => sign_ins}
end

# An env to call the app with n times: a copy of env for each, with a
# session (and a request body) of its own, since every call changes them.
def fresh_envs(env, session, count)
  Array.new(count) do
    env.merge("rack.session" => session.dup, "rack.input" => StringIO.new(""))
  end
end
