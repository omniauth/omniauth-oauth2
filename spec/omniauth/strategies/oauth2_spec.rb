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
        double("Request", :scheme => 'https', :url => 'https://rp.example.com', :env => {}, :query_string => {})
      end
    end

    it do
      response = instance.request_phase
      expect(response[0]).to be 302
      expect(response[1]['location']).to be_start_with "https://example.com/authorize"
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

    it "includes custom state in the authorize params" do
      instance = subject.new("abc", "def", :state => proc { "qux" })
      expect(instance.authorize_params.keys).to eq(["state"])
      expect(instance.session["omniauth.state"]).to eq("qux")
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

    describe 'exception handlings' do
      let(:params) do
        {"code" => "code", "state" => state}
      end

      before do
        allow_any_instance_of(OmniAuth::Strategies::OAuth2).to receive(:build_access_token).and_raise(exception)
      end

      {
        :invalid_credentials => [OAuth2::Error, OmniAuth::Strategies::OAuth2::CallbackError],
        :timeout => [Timeout::Error, Errno::ETIMEDOUT, OAuth2::TimeoutError, OAuth2::ConnectionError],
        :failed_to_connect => [SocketError]
      }.each do |error_type, exceptions|
        exceptions.each do |klass|
          context "when #{klass}" do
            let(:exception) { klass.new 'error' }

            it do
              expect(instance).to receive(:fail!).with(error_type, exception)
              instance.callback_phase
            end
          end
        end
      end
    end

    describe 'successful case' do
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
          double("Request", :scheme => 'https', :url => 'https://rp.example.com/callback', :env => {}, :query_string => {}, :params => params)
        end
        stub_request(:post, "https://example.com/token").to_return(:status => 200, :body => '{"access_token":"access_token","tokey_type":"bearer"}', :headers => {'Content-Type' => 'application/json'})
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
  end
end

describe OmniAuth::Strategies::OAuth2::CallbackError do
  let(:error) { Class.new(OmniAuth::Strategies::OAuth2::CallbackError) }
  describe "#message" do
    subject { error }
    it "includes all of the attributes" do
      instance = subject.new("error", "description", "uri")
      expect(instance.message).to match(/error/)
      expect(instance.message).to match(/description/)
      expect(instance.message).to match(/uri/)
    end
    it "includes all of the attributes" do
      instance = subject.new(nil, :symbol)
      expect(instance.message).to eq("symbol")
    end
  end
end
