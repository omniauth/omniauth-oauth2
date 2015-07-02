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

  describe "#authorize_params" do
    subject { fresh_strategy }

    it "includes any authorize params passed in the :authorize_params option" do
      instance = subject.new("abc", "def", :authorize_params => {:foo => "bar", :baz => "zip"})
      expect(instance.authorize_params["foo"]).to eq("bar")
      expect(instance.authorize_params["baz"]).to eq("zip")
    end

    it "includes top-level options that are marked as :authorize_options" do
      instance = subject.new("abc", "def", :authorize_options => [:scope, :foo, :state], :scope => "bar", :foo => "baz")
      expect(instance.authorize_params["scope"]).to eq("bar")
      expect(instance.authorize_params["foo"]).to eq("baz")
    end
  end

  describe "state handling" do
    SocialNetwork = Class.new(OmniAuth::Strategies::OAuth2)

    let(:client_options) { {:site => "https://graph.example.com"} }
    let(:instance) { SocialNetwork.new(-> env {}) }

    before do
      allow(SecureRandom).to receive(:hex).with(24).and_return("hex-1", "hex-2")
    end

    it "includes a state scoped to the client" do
      expect(instance.authorize_params["state"]).to eq("hex-1")
      expect(instance.session["omniauth.oauth2.state"]).to eq("SocialNetwork" => "hex-1")
    end

    context "once a state value has been generated" do
      before do
        instance.authorize_params
      end

      it "does not replace an existing session value" do
        expect(instance.authorize_params["state"]).to eq("hex-1")
        expect(instance.session["omniauth.oauth2.state"]).to eq("SocialNetwork" => "hex-1")
      end
    end

    context "on a successful callback" do
      let(:request) { double("Request", :params => {"code" => "auth-code", "state" => "hex-1"}) }
      let(:access_token) { double("AccessToken", :expired? => false, :expires? => false, :token => "access-token") }

      before do
        allow(instance).to receive(:request).and_return(request)
        allow(instance).to receive(:build_access_token).and_return(access_token)

        instance.authorize_params
        instance.callback_phase
      end

      it "removes the value from the session" do
        expect(instance.session["omniauth.oauth2.state"]).to eq({})
      end
    end
  end

  describe "#token_params" do
    subject { fresh_strategy }

    it "includes any authorize params passed in the :authorize_params option" do
      instance = subject.new("abc", "def", :token_params => {:foo => "bar", :baz => "zip"})
      expect(instance.token_params).to eq("foo" => "bar", "baz" => "zip")
    end

    it "includes top-level options that are marked as :authorize_options" do
      instance = subject.new("abc", "def", :token_options => [:scope, :foo], :scope => "bar", :foo => "baz")
      expect(instance.token_params).to eq("scope" => "bar", "foo" => "baz")
    end
  end

  describe "#callback_phase" do
    subject { fresh_strategy }
    it "calls fail with the client error received" do
      instance = subject.new("abc", "def")
      allow(instance).to receive(:request) do
        double("Request", :params => {"error_reason" => "user_denied", "error" => "access_denied"})
      end

      expect(instance).to receive(:fail!).with("user_denied", anything)
      instance.callback_phase
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
