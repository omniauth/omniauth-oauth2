require_relative "duel_helper"

# Every sample makes the same states and PKCE verifiers.
before_sample { DuelHelper::SeededRandom.reseed }

# The request phase: authorize_params, a new state, the sign-in stored in
# the session, and the redirect to the provider's authorize URL.
duel "request: redirect to the provider" do |n|
  once do
    @app = build_app
    @env = Rack::MockRequest.env_for("https://app.example.com/auth/example", :method => "POST")
  end
  envs = untimed { fresh_envs(@env, {}, n) }
  envs.each { |env| @app.call(env) }
end

duel "request: redirect with PKCE" do |n|
  once do
    @app = build_app(:pkce => true)
    @env = Rack::MockRequest.env_for("https://app.example.com/auth/example", :method => "POST")
  end
  envs = untimed { fresh_envs(@env, {}, n) }
  envs.each { |env| @app.call(env) }
end

# As many sign-ins in progress as the session keeps, so starting another
# drops the oldest.
duel "request: with the most sign-ins in progress" do |n|
  once do
    @app = build_app
    @env = Rack::MockRequest.env_for("https://app.example.com/auth/example", :method => "POST")
    @session = session_with_sign_ins(Array.new(OmniAuth::Strategies::OAuth2::MAX_STORED_SIGN_INS) { |i| format("%048x", i) })
  end
  envs = untimed { fresh_envs(@env, @session, n) }
  envs.each { |env| @app.call(env) }
end
