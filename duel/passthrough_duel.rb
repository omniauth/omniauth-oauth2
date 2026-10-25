require_relative "duel_helper"

# The strategy sits in front of every request the app gets, and most of
# them aren't for it.
duel "passthrough: a request for another path" do |n|
  once do
    @app = build_app
    @env = Rack::MockRequest.env_for("https://app.example.com/dashboard?page=2")
  end
  envs = untimed { fresh_envs(@env, {}, n) }
  envs.each { |env| @app.call(env) }
end
