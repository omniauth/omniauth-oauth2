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
end
