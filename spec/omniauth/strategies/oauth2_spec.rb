require 'spec_helper'

describe OmniAuth::Strategies::OAuth2 do
  def app; lambda{|env| [200, {}, ["Hello."]]} end
  let(:fresh_strategy){ Class.new(OmniAuth::Strategies::OAuth2) }

  describe '#client' do
    subject{ fresh_strategy }

    it 'should be initialized with symbolized client_options' do
      instance = subject.new(app, :client_options => {'authorize_url' => 'https://example.com'})
      instance.client.options[:authorize_url].should == 'https://example.com'
    end
  end

  describe '#authorize_params' do
    subject { fresh_strategy }

    it 'should include any authorize params passed in the :authorize_params option' do
      instance = subject.new('abc', 'def', :authorize_params => {:foo => 'bar', :baz => 'zip'})
      instance.authorize_params.should == {'foo' => 'bar', 'baz' => 'zip'}
    end

    it 'should include top-level options that are marked as :authorize_options' do
      instance = subject.new('abc', 'def', :authorize_options => [:scope, :foo], :scope => 'bar', :foo => 'baz')
      instance.authorize_params.should == {'scope' => 'bar', 'foo' => 'baz'}
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
