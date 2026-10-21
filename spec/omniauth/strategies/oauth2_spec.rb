require "helper"

describe OmniAuth::Strategies::OAuth2 do
  def app
    lambda do |_env|
      [200, {}, ["Hello."]]
    end
  end
  let(:fresh_strategy) { Class.new(OmniAuth::Strategies::OAuth2) }

  before do
    OmniAuth.config.test_mode = true
  end

  after do
    OmniAuth.config.test_mode = false
  end

  describe "Subclassing Behavior" do
    subject { fresh_strategy }

    it "performs the OmniAuth::Strategy included hook" do
      expect(OmniAuth.strategies).to include(OmniAuth::Strategies::OAuth2)
      expect(OmniAuth.strategies).to include(subject)
    end
  end

  describe "#client" do
    subject { fresh_strategy }

    it "is initialized with symbolized client_options" do
      instance = subject.new(app, :client_options => {"authorize_url" => "https://example.com"})
      expect(instance.client.options[:authorize_url]).to eq("https://example.com")
    end

    it "sets ssl options as connection options" do
      instance = subject.new(app, :client_options => {"ssl" => {"ca_path" => "foo"}})
      expect(instance.client.options[:connection_opts][:ssl]).to eq(:ca_path => "foo")
    end
  end

  describe "#request_phase" do
    subject(:instance) { fresh_strategy.new(app, :client_options => {"authorize_url" => "https://example.com/authorize"}) }

    before do
      allow(instance).to receive(:request) do
        double("Request", :scheme => "https", :url => "https://rp.example.com", :env => {}, :query_string => {})
      end
    end

    it do
      response = instance.request_phase
      expect(response[0]).to be 302
      expect(response[1]["location"]).to be_start_with "https://example.com/authorize"
    end
  end

  describe "#authorize_params" do
    subject { fresh_strategy }

    it "includes any authorize params passed in the :authorize_params option" do
      instance = subject.new("abc", "def", :authorize_params => {:foo => "bar", :baz => "zip"})
      expect(instance.authorize_params["foo"]).to eq("bar")
      expect(instance.authorize_params["baz"]).to eq("zip")
    end

    it "includes top-level options that are marked as :authorize_options" do
      instance = subject.new("abc", "def", :authorize_options => %i[scope foo state], :scope => "bar", :foo => "baz")
      expect(instance.authorize_params["scope"]).to eq("bar")
      expect(instance.authorize_params["foo"]).to eq("baz")
      expect(instance.authorize_params["state"]).not_to be_empty
    end

    it "includes random state in the authorize params" do
      instance = subject.new("abc", "def")
      expect(instance.authorize_params.keys).to eq(["state"])
      expect(instance.session["omniauth.state"]).not_to be_empty
    end

    it "sets callback_url in session" do
      instance = subject.new("abc", "def")
      instance.authorize_params
      expect(instance.session["omniauth.callback_url"]).not_to be_empty
    end

    it "sets the overridden redirect_uri from :authorize_params in session" do
      instance = subject.new("abc", "def", :authorize_params => {:redirect_uri => "https://override.example/cb"})
      instance.authorize_params
      expect(instance.session["omniauth.callback_url"]).to eq("https://override.example/cb")
    end

    it "sets a redirect_uri given as a proc via :authorize_options in session" do
      instance = subject.new("abc", "def", :authorize_options => [:redirect_uri], :redirect_uri => proc { "https://proc.example/cb" })
      instance.authorize_params
      expect(instance.session["omniauth.callback_url"]).to eq("https://proc.example/cb")
    end

    it "includes custom state in the authorize params" do
      instance = subject.new("abc", "def", :state => proc { "qux" })
      expect(instance.authorize_params.keys).to eq(["state"])
      expect(instance.session["omniauth.state"]).to eq("qux")
    end

    it "uses 24 random bytes for the state" do
      instance = subject.new("abc", "def")
      expect(instance.authorize_params["state"]).to match(/\A\h{48}\z/)
    end

    it "doesn't make up a session outside test mode" do
      OmniAuth.config.test_mode = false
      instance = subject.new("abc", "def")
      instance.instance_variable_set(:@env, {})
      expect { instance.authorize_params }.to raise_error(NoMethodError)
      expect(instance.env).to eq({})
    end

    it "includes PKCE parameters if enabled" do
      instance = subject.new("abc", "def", :pkce => true)
      expect(instance.authorize_params[:code_challenge]).to be_a(String)
      expect(instance.authorize_params[:code_challenge_method]).to eq("S256")
      expect(instance.session["omniauth.pkce.verifier"]).to be_a(String)
    end
  end

  describe "#token_params" do
    subject { fresh_strategy }

    it "includes any authorize params passed in the :authorize_params option" do
      instance = subject.new("abc", "def", :token_params => {:foo => "bar", :baz => "zip"})
      expect(instance.token_params).to eq("foo" => "bar", "baz" => "zip")
    end

    it "includes top-level options that are marked as :authorize_options" do
      instance = subject.new("abc", "def", :token_options => %i[scope foo], :scope => "bar", :foo => "baz")
      expect(instance.token_params).to eq("scope" => "bar", "foo" => "baz")
    end

    it "includes the PKCE code_verifier if enabled" do
      instance = subject.new("abc", "def", :pkce => true)
      # setup session
      instance.authorize_params
      expect(instance.token_params[:code_verifier]).to be_a(String)
    end
  end

  describe "#build_access_token" do
    subject { fresh_strategy }
    let(:request_double) { double("Request", :params => {}) }
    let(:client_double) { double }
    let(:strategy_double) { double }
    let(:callback_url) { "http://abc.def/auth/abc/callback" }

    it "uses callback_url stored in session" do
      instance = subject.new("abc", "def")

      allow(instance).to receive(:request).and_return(request_double)
      allow(instance).to receive(:session).and_return({"omniauth.callback_url" => callback_url})
      allow(instance).to receive(:client).and_return(client_double)
      allow(client_double).to receive(:auth_code).and_return(strategy_double)

      expect(strategy_double).to receive(:get_token)
        .with(nil, hash_including(:redirect_uri => callback_url), {})

      instance.send(:build_access_token)
    end

    it "removes the stored callback_url from session once used" do
      instance = subject.new("abc", "def")
      session = {"omniauth.callback_url" => callback_url}

      allow(instance).to receive(:request).and_return(request_double)
      allow(instance).to receive(:session).and_return(session)
      allow(instance).to receive(:client).and_return(client_double)
      allow(client_double).to receive(:auth_code).and_return(strategy_double)
      allow(strategy_double).to receive(:get_token)

      instance.send(:build_access_token)

      expect(session).not_to have_key("omniauth.callback_url")
    end

    it "falls back to the current callback_url when none is stored in session" do
      instance = subject.new("abc", "def")

      allow(instance).to receive(:request).and_return(request_double)
      allow(instance).to receive(:session).and_return({})
      allow(instance).to receive(:callback_url).and_return(callback_url)
      allow(instance).to receive(:client).and_return(client_double)
      allow(client_double).to receive(:auth_code).and_return(strategy_double)

      expect(strategy_double).to receive(:get_token)
        .with(nil, hash_including(:redirect_uri => callback_url), {})

      instance.send(:build_access_token)
    end

    it "sends the same redirect_uri as the request phase when the request had a query string" do
      session = {}
      instance = subject.new("abc", "def")
      instance.instance_variable_set(:@env, Rack::MockRequest.env_for("http://abc.def/auth/abc?origin=home", "rack.session" => session))
      request_phase_uri = instance.callback_url
      instance.authorize_params

      instance.instance_variable_set(:@env, Rack::MockRequest.env_for("http://abc.def/auth/abc/callback?code=c&state=s", "rack.session" => session))
      instance.instance_variable_set(:@request, nil)
      allow(instance).to receive(:client).and_return(client_double)
      allow(client_double).to receive(:auth_code).and_return(strategy_double)

      expect(strategy_double).to receive(:get_token)
        .with("c", hash_including(:redirect_uri => request_phase_uri), {})

      instance.send(:build_access_token)
    end
  end

  describe "#callback_phase" do
    subject(:instance) { fresh_strategy.new("abc", "def") }

    let(:params) { {"error_reason" => "user_denied", "error" => "access_denied", "state" => state} }
    let(:state) { "secret" }

    before do
      allow(instance).to receive(:request) do
        double("Request", :params => params)
      end

      allow(instance).to receive(:session) do
        double("Session", :delete => state)
      end
    end

    it "calls fail with the error received" do
      expect(instance).to receive(:fail!).with("user_denied", anything)

      instance.callback_phase
    end

    it "calls fail with the error received if state is missing and CSRF verification is disabled" do
      params["state"] = nil
      instance.options.provider_ignores_state = true

      expect(instance).to receive(:fail!).with("user_denied", anything)

      instance.callback_phase
    end

    it "calls fail with a CSRF error if the state is missing" do
      params["state"] = nil

      expect(instance).to receive(:fail!).with(:csrf_detected, anything)
      instance.callback_phase
    end

    it "calls fail with a CSRF error if the state is invalid" do
      params["state"] = "invalid"

      expect(instance).to receive(:fail!).with(:csrf_detected, anything)
      instance.callback_phase
    end

    describe "exception handlings" do
      let(:params) do
        {"code" => "code", "state" => state}
      end

      before do
        allow_any_instance_of(OmniAuth::Strategies::OAuth2).to receive(:build_access_token).and_raise(exception)
      end

      {
        :invalid_credentials => [OAuth2::Error, OmniAuth::Strategies::OAuth2::CallbackError],
        :timeout => [Timeout::Error, Errno::ETIMEDOUT, OAuth2::TimeoutError, OAuth2::ConnectionError],
        :failed_to_connect => [SocketError],
      }.each do |error_type, exceptions|
        exceptions.each do |klass|
          context "when #{klass}" do
            let(:exception) { klass.new "error" }

            it do
              expect(instance).to receive(:fail!).with(error_type, exception)
              instance.callback_phase
            end
          end
        end
      end
    end

    describe "successful case" do
      def app
        lambda do |_env|
          [200, {}, ["Hello."]]
        end
      end

      let(:instance) do
        fresh_strategy.new(app, :client_options => {"token_url" => "https://example.com/token"})
      end
      let(:params) do
        {"code" => "code", "state" => state}
      end

      before do
        allow(instance).to receive(:env).and_return({})
        allow(instance).to receive(:request) do
          double("Request", :scheme => "https", :url => "https://rp.example.com/callback", :env => {}, :query_string => {}, :params => params)
        end
        stub_request(:post, "https://example.com/token").to_return(:status => 200, :body => '{"access_token":"access_token","tokey_type":"bearer"}', :headers => {"Content-Type" => "application/json"})
      end

      it do
        instance.callback_phase
        expect(instance.access_token).to be_instance_of OAuth2::AccessToken
      end
    end
  end

  describe "#secure_compare" do
    subject { fresh_strategy }

    it "returns true when the two inputs are the same and false otherwise" do
      instance = subject.new("abc", "def")
      expect(instance.send(:secure_compare, "a", "a")).to be true
      expect(instance.send(:secure_compare, "b", "a")).to be false
    end

    it "returns false when the inputs differ in more than one byte" do
      expect(fresh_strategy.new("abc", "def").send(:secure_compare, "ab", "ba")).to be false
    end

    it "returns false when one input starts with the other" do
      instance = fresh_strategy.new("abc", "def")
      expect(instance.send(:secure_compare, "secret!", "secret")).to be false
      expect(instance.send(:secure_compare, "secret", "secret!")).to be false
    end
  end

  describe "#options_for" do
    it "returns the set options, with symbol keys, calling any that are callable with the env" do
      instance = fresh_strategy.new("abc", "def", :authorize_options => ["scope", :prompt, :login_hint], :scope => "email", :prompt => ->(env) { env.fetch("prompt") }, :login_hint => nil)
      instance.instance_variable_set(:@env, "prompt" => "consent")
      expect(instance.send(:options_for, "authorize")).to eq(:scope => "email", :prompt => "consent")
    end
  end

  describe "#deep_symbolize" do
    it "symbolizes the keys of nested hashes, including Hashie::Mash ones" do
      options = OmniAuth::Strategy::Options.new("a" => {"b" => 1}, "c" => 2)
      expect(fresh_strategy.new("abc", "def").send(:deep_symbolize, options)).to eq(:a => {:b => 1}, :c => 2)
    end
  end
end

describe OmniAuth::Strategies::OAuth2::CallbackError do
  let(:error) { Class.new(OmniAuth::Strategies::OAuth2::CallbackError) }
  describe "#message" do
    subject { error }
    it "includes all of the attributes" do
      instance = subject.new("error", "description", "uri")
      expect(instance.message).to eq("error | description | uri")
    end
    it "defaults the reason and URI to nil" do
      instance = subject.new("error")
      expect([instance.error, instance.error_reason, instance.error_uri, instance.message]).to eq(["error", nil, nil, "error"])
    end

    it "includes all of the attributes" do
      instance = subject.new(nil, :symbol)
      expect(instance.message).to eq("symbol")
    end
  end
end

# Mutant runs a method's mutations against the specs that describe that
# method, so list the methods these end-to-end specs exercise.
FLOW_METHODS = %w[client request_phase authorize_params token_params callback_phase csrf_detected? pkce_authorize_params pkce_token_params build_access_token deep_symbolize options_for secure_compare].freeze

describe "OmniAuth::Strategies::OAuth2 request and callback", :mutant_expression => FLOW_METHODS.map { |name| "OmniAuth::Strategies::OAuth2##{name}" } do
  let(:strategy) do
    Class.new(OmniAuth::Strategies::OAuth2) do
      option :name, "example"
      option :client_options, :site => "https://example.com"
    end
  end
  let(:options) { {} }
  let(:strategies) { [] }
  let(:app) do
    strategy_class = strategy
    strategy_options = options
    seen = strategies
    Rack::Builder.new do
      use OmniAuth::Test::PhonySession
      use strategy_class, "abc", "def", strategy_options
      run lambda { |env|
        seen << env["omniauth.strategy"]
        [200, {}, [JSON.generate(env["omniauth.auth"]["credentials"])]]
      }
    end.to_app
  end
  let(:session) { {"omniauth.state" => "secret"} }

  around do |example|
    validation_phase = OmniAuth.config.request_validation_phase
    OmniAuth.config.request_validation_phase = nil
    example.run
  ensure
    OmniAuth.config.request_validation_phase = validation_phase
  end

  def stub_token(body, grant_type = "authorization_code")
    stub_request(:post, "https://example.com/oauth/token")
      .with(:body => hash_including("grant_type" => grant_type))
      .to_return(:body => JSON.generate(body), :headers => {"Content-Type" => "application/json"})
  end

  def callback
    get "/auth/example/callback", {"code" => "code", "state" => "secret"}, "rack.session" => session
    JSON.parse(last_response.body)
  end

  it "redirects the request phase to the authorize URL with a state stored in the session" do
    session = {}
    post "/auth/example", {}, "rack.session" => session
    location = URI.parse(last_response.headers["Location"])
    query = Rack::Utils.parse_query(location.query)
    expect(location.to_s).to start_with("https://example.com/oauth/authorize?")
    expect(query).to include("client_id" => "abc", "response_type" => "code", "redirect_uri" => "http://example.org/auth/example/callback")
    expect(query["state"]).to eq(session["omniauth.state"])
  end

  it "exchanges the code for a token that doesn't expire" do
    stub_token("access_token" => "token")
    expect(callback).to eq("token" => "token", "expires" => false)
    expect(a_request(:post, "https://example.com/oauth/token").with(:body => hash_including("code" => "code"))).to have_been_made
  end

  it "includes the expiry and refresh token of a token that expires" do
    expires_at = Time.now.to_i + 3600
    stub_token("access_token" => "token", "refresh_token" => "refresh", "expires_at" => expires_at)
    expect(callback).to eq("token" => "token", "refresh_token" => "refresh", "expires_at" => expires_at, "expires" => true)
  end

  it "leaves out the refresh token when an expiring token has none" do
    expires_at = Time.now.to_i + 3600
    stub_token("access_token" => "token", "expires_at" => expires_at)
    expect(callback).to eq("token" => "token", "expires_at" => expires_at, "expires" => true)
  end

  it "refreshes a token that has already expired" do
    expires_at = Time.now.to_i + 3600
    stub_token("access_token" => "expired", "refresh_token" => "refresh", "expires_at" => Time.now.to_i - 60)
    stub_token({"access_token" => "fresh", "refresh_token" => "new refresh", "expires_at" => expires_at}, "refresh_token")
    expect(callback).to eq("token" => "fresh", "refresh_token" => "new refresh", "expires_at" => expires_at, "expires" => true)
  end

  def authorize_query(session = {})
    post "/auth/example", {}, "rack.session" => session
    Rack::Utils.parse_query(URI.parse(last_response.headers["Location"]).query)
  end

  def token_request
    requests = WebMock::RequestRegistry.instance.requested_signatures.hash.keys.select { |request| request.uri.path == "/oauth/token" }
    expect(requests.size).to eq(1)
    requests.first
  end

  def token_request_body
    URI.decode_www_form(token_request.body)
  end

  def callback_error
    last_request.env["omniauth.error"]
  end

  it "sends exactly the client ID, response type, redirect URI, and a 24-byte state, and stores the state" do
    session = {}
    query = authorize_query(session)
    expect(query.keys).to contain_exactly("client_id", "response_type", "redirect_uri", "state")
    expect(query).to include("client_id" => "abc", "response_type" => "code", "redirect_uri" => "http://example.org/auth/example/callback")
    expect(query["state"]).to match(/\A\h{48}\z/)
    expect(session.keys).to contain_exactly("omniauth.params", "omniauth.state", "omniauth.callback_url")
    expect(session["omniauth.callback_url"]).to eq(query["redirect_uri"])
    expect(session["omniauth.state"]).to eq(query["state"])
  end

  context "with authorize options" do
    let(:strategy) do
      Class.new(OmniAuth::Strategies::OAuth2) do
        option :name, "example"
        option :client_options, :site => "https://example.com"
        option :authorize_options, %i[scope prompt login_hint]
        option :login_hint, nil
      end
    end
    let(:options) { {:scope => "email", :prompt => ->(env) { env["PATH_INFO"] }, :authorize_params => {:access_type => "offline"}} }

    it "adds the authorize params and the set authorize options, calling callable ones with the env" do
      query = authorize_query
      expect(query).to include("scope" => "email", "prompt" => "/auth/example", "access_type" => "offline")
      expect(query).not_to have_key("login_hint")
    end
  end

  context "with PKCE" do
    let(:options) { {:pkce => true} }

    it "sends the S256 challenge for a 64-byte verifier it stores in the session" do
      session = {}
      query = authorize_query(session)
      verifier = session.fetch("omniauth.pkce.verifier")
      expect(verifier).to match(/\A\h{128}\z/)
      expect(query).to include("code_challenge" => Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), :padding => false), "code_challenge_method" => "S256")
    end

    it "sends the stored verifier with the token request and removes it from the session" do
      stub_token("access_token" => "token")
      session["omniauth.pkce.verifier"] = "verifier"
      callback
      expect(token_request_body).to include(%w[code_verifier verifier])
      expect(session).not_to have_key("omniauth.pkce.verifier")
    end
  end

  context "with custom PKCE options" do
    let(:options) { {:pkce => true, :pkce_options => {:code_challenge => ->(verifier) { "challenge for #{verifier}" }, :code_challenge_method => "plain"}} }

    it "uses them for the challenge" do
      session = {}
      query = authorize_query(session)
      expect(query).to include("code_challenge" => "challenge for #{session.fetch('omniauth.pkce.verifier')}", "code_challenge_method" => "plain")
    end
  end

  it "doesn't send or remove a PKCE verifier without PKCE" do
    stub_token("access_token" => "token")
    session["omniauth.pkce.verifier"] = "verifier"
    callback
    expect(token_request_body.map(&:first)).not_to include("code_verifier")
    expect(session).to include("omniauth.pkce.verifier" => "verifier")
  end

  it "sends exactly the grant type, code, and redirect URI, authenticated with the client ID and secret" do
    stub_token("access_token" => "token")
    callback
    expect(token_request_body).to contain_exactly(%w[grant_type authorization_code], %w[code code], ["redirect_uri", "http://example.org/auth/example/callback?code=code&state=secret"])
    expect(token_request.headers["Authorization"]).to eq("Basic #{['abc:def'].pack('m0')}")
  end

  context "with token params and options" do
    let(:strategy) do
      Class.new(OmniAuth::Strategies::OAuth2) do
        option :name, "example"
        option :client_options, :site => "https://example.com"
        option :token_options, %i[audience]
      end
    end
    let(:options) { {:audience => ->(env) { env["PATH_INFO"] }, :token_params => {:redirect_uri => "https://example.org/registered", :resource => "api"}} }

    it "sends them, letting a token param replace the redirect URI" do
      stub_token("access_token" => "token")
      callback
      expect(token_request_body).to contain_exactly(%w[grant_type authorization_code], %w[code code], ["redirect_uri", "https://example.org/registered"], %w[resource api], ["audience", "/auth/example/callback"])
    end
  end

  context "with auth token params" do
    let(:options) { {:auth_token_params => {:mode => :query, :param_name => "token"}} }

    it "passes them to oauth2 with symbol keys, as it documents" do
      stub_token("access_token" => "token")
      expect_any_instance_of(OAuth2::Strategy::AuthCode).to receive(:get_token).with("code", anything, satisfy { |opts| opts.keys == %i[mode param_name] && opts.values == [:query, "token"] }).and_call_original
      callback
    end

    it "builds the access token with them" do
      stub_token("access_token" => "token")
      callback
      expect(strategies.last.access_token.options).to include(:mode => :query, :param_name => "token")
    end
  end

  it "fails with :invalid_credentials when the provider rejects a callback without a code" do
    stub_request(:post, "https://example.com/oauth/token")
      .to_return(:status => 400, :body => JSON.generate("error" => "invalid_request"), :headers => {"Content-Type" => "application/json"})
    get "/auth/example/callback", {"state" => "secret"}, "rack.session" => session
    expect(token_request_body).to include(["code", ""])
    expect(last_request.env["omniauth.error.type"]).to eq(:invalid_credentials)
  end

  it "fails with :csrf_detected when the state doesn't match" do
    get "/auth/example/callback", {"code" => "code", "state" => "secret!"}, "rack.session" => session
    expect(last_request.env["omniauth.error.type"]).to eq(:csrf_detected)
    expect(callback_error).to be_a(OmniAuth::Strategies::OAuth2::CallbackError)
    expect([callback_error.error, callback_error.error_reason, callback_error.error_uri]).to eq([:csrf_detected, "CSRF detected", nil])
  end

  context "when the provider ignores state" do
    let(:options) { {:provider_ignores_state => true} }

    it "accepts a callback without one" do
      stub_token("access_token" => "token")
      get "/auth/example/callback", {"code" => "code"}, "rack.session" => session
      expect(JSON.parse(last_response.body)).to eq("token" => "token", "expires" => false)
    end
  end

  it "fails with :csrf_detected when there's no state" do
    get "/auth/example/callback", {"code" => "code"}, "rack.session" => session
    expect(last_request.env["omniauth.error.type"]).to eq(:csrf_detected)
  end

  it "fails with :csrf_detected when the session has no state" do
    get "/auth/example/callback", {"code" => "code", "state" => "secret"}, "rack.session" => {}
    expect(last_request.env["omniauth.error.type"]).to eq(:csrf_detected)
  end

  it "fails with :csrf_detected when neither the callback nor the session has a state" do
    get "/auth/example/callback", {"code" => "code"}, "rack.session" => {}
    expect(last_request.env["omniauth.error.type"]).to eq(:csrf_detected)
  end

  it "fails with :csrf_detected when the state isn't a string" do
    get "/auth/example/callback", {"code" => "code", "state" => ["secret"]}, "rack.session" => session
    expect(last_request.env["omniauth.error.type"]).to eq(:csrf_detected)
  end

  it "fails with the provider's error, description, and URI" do
    get "/auth/example/callback", {"state" => "secret", "error" => "access_denied", "error_description" => "The user said no", "error_uri" => "https://example.com/errors"}, "rack.session" => session
    expect(last_request.env["omniauth.error.type"]).to eq(:access_denied)
    expect(callback_error).to be_a(OmniAuth::Strategies::OAuth2::CallbackError)
    expect([callback_error.error, callback_error.error_reason, callback_error.error_uri]).to eq(["access_denied", "The user said no", "https://example.com/errors"])
  end

  it "fails with the provider's error reason when there's no error" do
    get "/auth/example/callback", {"state" => "secret", "error_reason" => "user_denied"}, "rack.session" => session
    expect(last_request.env["omniauth.error.type"]).to eq(:user_denied)
    expect([callback_error.error, callback_error.error_reason, callback_error.error_uri]).to eq([nil, "user_denied", nil])
  end

  it "fails with the provider's error when there's no description or reason" do
    get "/auth/example/callback", {"state" => "secret", "error" => "access_denied"}, "rack.session" => session
    expect(last_request.env["omniauth.error.type"]).to eq(:access_denied)
    expect([callback_error.error, callback_error.error_reason, callback_error.error_uri]).to eq(["access_denied", nil, nil])
  end

  it "prefers the provider's error reason, and falls back to it for the description" do
    get "/auth/example/callback", {"state" => "secret", "error" => "access_denied", "error_reason" => "user_denied"}, "rack.session" => session
    expect(last_request.env["omniauth.error.type"]).to eq(:user_denied)
    expect([callback_error.error, callback_error.error_reason, callback_error.error_uri]).to eq(["access_denied", "user_denied", nil])
  end
end
