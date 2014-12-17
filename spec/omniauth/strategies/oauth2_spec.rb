require 'helper'

describe OmniAuth::Strategies::OAuth2 do
  def app
    lambda do |_env|
      [200, {}, ['Hello.']]
    end
  end

  let(:fresh_strategy) { Class.new(OmniAuth::Strategies::OAuth2) }

  before do
    OmniAuth.config.test_mode = true
  end

  after do
    OmniAuth.config.test_mode = false
  end

  describe '#client' do
    subject { fresh_strategy }

    it 'is initialized with symbolized client_options' do
      instance = subject.new(app, :client_options => {'authorize_url' => 'https://example.com'})
      expect(instance.client.options[:authorize_url]).to eq('https://example.com')
    end

    it 'sets ssl options as connection options' do
      instance = subject.new(app, :client_options => {'ssl' => {'ca_path' => 'foo'}})
      expect(instance.client.options[:connection_opts][:ssl]).to eq(:ca_path => 'foo')
    end
  end

  describe '#authorize_params' do
    subject { fresh_strategy }

    it 'includes any authorize params passed in the :authorize_params option' do
      instance = subject.new('abc', 'def', :authorize_params => {:foo => 'bar', :baz => 'zip'})
      expect(instance.authorize_params['foo']).to eq('bar')
      expect(instance.authorize_params['baz']).to eq('zip')
    end

    it 'includes top-level options that are marked as :authorize_options' do
      instance = subject.new('abc', 'def', :authorize_options => [:scope, :foo, :state], :scope => 'bar', :foo => 'baz')
      expect(instance.authorize_params['scope']).to eq('bar')
      expect(instance.authorize_params['foo']).to eq('baz')
    end

    it 'includes random state in the authorize params' do
      instance = subject.new('abc', 'def')
      expect(instance.authorize_params.keys).to eq(['state'])
      expect(instance.session['omniauth.state']).not_to be_empty
    end
  end

  describe '#token_params' do
    subject { fresh_strategy }

    it 'includes any authorize params passed in the :authorize_params option' do
      instance = subject.new('abc', 'def', :token_params => {:foo => 'bar', :baz => 'zip'})
      expect(instance.token_params).to eq('foo' => 'bar', 'baz' => 'zip')
    end

    it 'includes top-level options that are marked as :authorize_options' do
      instance = subject.new('abc', 'def', :token_options => [:scope, :foo], :scope => 'bar', :foo => 'baz')
      expect(instance.token_params).to eq('scope' => 'bar', 'foo' => 'baz')
    end
  end

  describe '#callback_phase' do
    before :all do
      @env_hash = {
        :client_id => 'abc', :client_secret => 'def', :provider_ignores_state => true, :code => '4/def', :callback_path => 'https://callback_path', :client_options => {:site => 'https://api.somesite.com'}
      }

      # Fake having a session.
      # Can't use the ActionController:TestCase methods in this context
      OmniAuth::Strategies::OAuth2.class_eval %"
                                        def session=(var)
                                          @session = var
                                        end
                                        def session
                                          @session
                                        end
                                        "
    end
    subject { fresh_strategy }
    it 'calls fail with the client error received' do
      instance = subject.new('abc', 'def')
      allow(instance).to receive(:request) do
        double('Request', :params => {'error_reason' => 'user_denied', 'error' => 'access_denied'})
      end

      expect(instance).to receive(:fail!).with('user_denied', anything)
      instance.callback_phase
    end

    it 'should accept callback params from the request via params[] hash' do
      instance = subject.new('abc', 'def')
      instance.session = {'omniauth.state' => 'abc'} # fake session
      allow(instance).to receive(:request) do
        double('Request', :params => {'code' => @env_hash['code'], 'state' => 'abc'})
      end

      expect(instance).to receive(:build_access_token)

      # We aren't testing the whole method.
      # if it has received build_access_token then this test has passed
      # So this exception later is because we haven't set up all of the expected state
      expect do
        instance.callback_phase
      end.to raise_error(
               NoMethodError,
               "undefined method `expired?' for nil:NilClass",
           )
    end

    it 'should accept callback params as constructor options' do
      instance = subject.new(@env_hash[:client_id], @env_hash[:client_secret], :provider_ignores_state => true, :code => @env_hash['code'])
      allow(instance).to receive(:request) do
        double('Request', :params => {})
      end

      expect(instance).to receive(:build_access_token)

      # We aren't testing the whole method.
      # if it has received build_access_token then this test has passed
      # So this exception later is because we haven't set up all of the expected state
      expect do
        instance.callback_phase
      end.to raise_error(
               NoMethodError,
               "undefined method `expired?' for nil:NilClass",
           )
    end

    it 'should, given sane params, return an auth_hash' do
      instance = subject.new(app, @env_hash)
      token = '1/fFAGRNJru1FTz70BzhT3Zg'
      expires = 3920

      allow(instance).to receive(:request) do
        double('Request', :params => {}, :scheme => 'scheme', :url => 'url')
      end

      stub_request(:post, 'https://api.somesite.com/oauth/token').with(
          :body => {
            'client_id' => @env_hash[:client_id],
            'client_secret' => @env_hash[:client_secret],
            'code' => @env_hash[:code],
            'grant_type' => 'authorization_code',
            'redirect_uri' => @env_hash[:callback_path],
          },
          :headers => {
            'Accept' => '*/*',
            'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'Content-Type' => 'application/x-www-form-urlencoded',
            'User-Agent' => 'Faraday v0.9.0',
          },
      ).to_return(
          :status => 200,
          :headers => {:content_type => 'application/json'},
          :body => "{\"access_token\":\"#{token}\",\"expires_in\":\"#{expires}\",\"token_type\":\"Bearer\"}",
      )

      instance.callback_phase

      auth_hash = instance.env['omniauth.auth']

      # The auth hash should be the expected type
      expect(auth_hash).to be_a OmniAuth::AuthHash

      # The refresh token should match
      expect(auth_hash.credentials.token).to eql(token)

      # The expiry should be correct
      expect(auth_hash.credentials.expires_at).to be_within(60).of((Time.now + expires).to_i) # 60 second buffer in case our test runs slow
    end
  end
end

describe OmniAuth::Strategies::OAuth2::CallbackError do
  let(:error) { Class.new(OmniAuth::Strategies::OAuth2::CallbackError) }
  describe '#message' do
    subject { error }
    it 'includes all of the attributes' do
      instance = subject.new('error', 'description', 'uri')
      expect(instance.message).to match(/error/)
      expect(instance.message).to match(/description/)
      expect(instance.message).to match(/uri/)
    end
    it 'includes all of the attributes' do
      instance = subject.new(nil, :symbol)
      expect(instance.message).to eq('symbol')
    end
  end
end
