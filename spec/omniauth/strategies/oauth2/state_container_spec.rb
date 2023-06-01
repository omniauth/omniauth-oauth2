require "helper"

describe OmniAuth::Strategies::OAuth2::StateContainer do
  let(:state) { "random_state" }
  let(:oauth2) { double("OAuth2", session: {}) }

  describe "#save_state" do
    it "saves the state in the session" do
      subject.store(oauth2, state)

      expect(oauth2.session["omniauth.state"]).to eq(state)
    end
  end

  describe "#take_state" do
    before do
      subject.store(oauth2, state)
    end

    it "removes the state from the session" do
      expect(oauth2.session).to include("omniauth.state")

      taken_state = subject.take(oauth2)

      expect(oauth2.session).not_to include("omniauth.state")
      expect(taken_state).to eq(state)
    end
  end
end
