require 'spec_helper'

describe OmniAuth::Strategies::OAuth2 do
  def app; lambda{|env| [200, {}, ["Hello."]]} end
  let(:fresh_strategy){ Class.new(OmniAuth::Strategies::OAuth2) }

  before do
    OmniAuth.config.test_mode = true
  end

  after do
    OmniAuth.config.test_mode = false
  end

  describe '#client' do
    subject{ fresh_strategy }

    it 'should be initialized with symbolized client_options' do
      instance = subject.new(app, :client_options => {'authorize_url' => 'https://example.com'})
      instance.client.options[:authorize_url].should == 'https://example.com'
    end

    it 'should set ssl options as connection options' do
      instance = subject.new(app, :client_options => {'ssl' => {'ca_path' => 'foo'}})
      instance.client.options[:connection_opts][:ssl] =~ {:ca_path => 'foo'}
    end
  end

  describe '#authorize_params' do
    subject { fresh_strategy }

    it 'should include any authorize params passed in the :authorize_params option' do
      instance = subject.new('abc', 'def', :authorize_params => {:foo => 'bar', :baz => 'zip', :state => '123'})
      instance.authorize_params.should == {'foo' => 'bar', 'baz' => 'zip', 'state' => '123'}
    end

    it 'should include top-level options that are marked as :authorize_options' do
      instance = subject.new('abc', 'def', :authorize_options => [:scope, :foo], :scope => 'bar', :foo => 'baz', :authorize_params => {:state => '123'})
      instance.authorize_params.should == {'scope' => 'bar', 'foo' => 'baz', 'state' => '123'}
    end

    it 'should include random state in the authorize params' do
      instance = subject.new('abc', 'def')
      instance.authorize_params.keys.should == ['state']
      instance.session['omniauth.state'].should_not be_empty
      instance.session['omniauth.state'].should == instance.authorize_params['state']
    end
  end

  describe '#token_params' do
    subject { fresh_strategy }

    it 'should include any authorize params passed in the :authorize_params option' do
      instance = subject.new('abc', 'def', :token_params => {:foo => 'bar', :baz => 'zip'})
      instance.token_params.should == {'foo' => 'bar', 'baz' => 'zip'}
    end

    it 'should include top-level options that are marked as :authorize_options' do
      instance = subject.new('abc', 'def', :token_options => [:scope, :foo], :scope => 'bar', :foo => 'baz')
      instance.token_params.should == {'scope' => 'bar', 'foo' => 'baz'}
    end
  end
end
