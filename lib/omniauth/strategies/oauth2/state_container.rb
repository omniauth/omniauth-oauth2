module OmniAuth
  module Strategies
    class OAuth2
      class StateContainer
        def store(oauth2, state)
          oauth2.session["omniauth.state"] = state
        end

        def take(oauth2)
          oauth2.session.delete("omniauth.state")
        end
      end
    end
  end
end
