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
    OmniAuth.config.full_host = "test"
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.full_host = "test"
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

    it "includes random state in the authorize params" do
      instance = subject.new("abc", "def")
      params = instance.authorize_params
      expect(params.keys).to eq(["state"])
      expect(instance.session["omniauth.state.#{params[:state]}"]).not_to be_empty
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
      instance.authorize_params # init env and set state
      allow(instance).to receive(:request) do
        double("Request", :params => {"error_reason" => "user_denied", "error" => "access_denied"})
      end

      expect(instance).to receive(:fail!).with("user_denied", anything)
      instance.callback_phase
      expect(instance.env["omniauth.auth"]).to be_nil
    end

    it "calls fail with csrf_detected when state is incorrect" do
      instance = subject.new("abc", "def")
      instance.authorize_params # init env and set state
      allow(instance).to receive(:request) do
        double("Request", :params => {"state" => "invalid_state"})
      end

      expect(instance).to receive(:fail!).with(:csrf_detected, anything)
      instance.callback_phase
      expect(instance.env["omniauth.auth"]).to be_nil
    end

    it "succeeds" do
      app = double("RackApp")
      instance = subject.new(app, "def")
      params = instance.authorize_params
      allow(instance).to receive(:request) do
        double("Request", :params => {"state" => params[:state]})
      end
      allow(instance).to receive(:build_access_token) do
        double("OAuht2::AccessToken", :expires? => false, :expired? => false, :token => "access token")
      end

      expect(app).to receive(:call) do |env|
        expect(env["omniauth.auth"]["credentials"]).to eq("token" => "access token", "expires" => false)
      end
      instance.callback_phase
      expect(instance.env["omniauth.auth"]).to_not be_nil
    end

    it "allows for two concurrent authorizations on the same session" do
      app = double("RackApp")
      instance = subject.new(app, "def")
      allow(instance).to receive(:build_access_token) do
        double("OAuht2::AccessToken", :expires? => false, :expired? => false, :token => "access token")
      end

      states = []

      2.times do
        params = instance.authorize_params
        states << params[:state]
      end

      expect(app).to receive(:call).twice
      expect(instance).to_not receive(:fail!)
      states.each do |state|
        allow(instance).to receive(:request) do
          double("Request", :params => {"state" => state})
        end
        instance.callback_phase
      end
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
