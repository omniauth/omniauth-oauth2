require_relative "duel_helper"

# The callback phase: the state checked against the stored sign-ins, the
# code exchanged for a token (answered in process), and the AuthHash.
def callback_env(state)
  Rack::MockRequest.env_for("https://app.example.com/auth/example/callback?code=SplxlOBeZQQYbYS6WxSbIA&state=#{state}")
end

duel "callback: exchange the code for an AuthHash" do |n|
  once do
    @app = build_app
    state = states(1).first
    @env = callback_env(state)
    @session = session_with_sign_ins([state])
  end
  envs = untimed { fresh_envs(@env, @session, n) }
  envs.each { |env| @app.call(env) }
end

duel "callback: exchange the code with PKCE" do |n|
  once do
    @app = build_app(:pkce => true)
    state = states(1).first
    @env = callback_env(state)
    @session = session_with_sign_ins([state], :pkce => true)
  end
  envs = untimed { fresh_envs(@env, @session, n) }
  envs.each { |env| @app.call(env) }
end

# As many sign-ins in progress as the session keeps, with the callback's
# the newest, so finding it compares every state.
duel "callback: with the most sign-ins in progress" do |n|
  once do
    @app = build_app
    stored = states(OmniAuth::Strategies::OAuth2::MAX_STORED_SIGN_INS)
    @env = callback_env(stored.last)
    @session = session_with_sign_ins(stored)
  end
  envs = untimed { fresh_envs(@env, @session, n) }
  envs.each { |env| @app.call(env) }
end

# A state that matches no stored sign-in: a forged callback, or one whose
# sign-in the session dropped. It fails without asking for a token.
duel "callback: reject an unknown state" do |n|
  once do
    @app = build_app
    @env = callback_env("0" * 48)
    @session = session_with_sign_ins(states(1))
  end
  envs = untimed { fresh_envs(@env, @session, n) }
  envs.each { |env| @app.call(env) }
end
