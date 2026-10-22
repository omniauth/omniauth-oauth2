require "oauth2"
require "omniauth"
require "securerandom"
require "socket"       # for SocketError
require "timeout"      # for Timeout::Error

module OmniAuth
  module Strategies
    # Authentication strategy for connecting with APIs constructed using
    # the [OAuth 2.0 Specification](http://tools.ietf.org/html/draft-ietf-oauth-v2-10).
    # You must generally register your application with the provider and
    # utilize an application id and secret in order to authenticate using
    # OAuth 2.0.
    class OAuth2
      include OmniAuth::Strategy

      def self.inherited(subclass)
        Strategy.included(subclass)
      end

      args %i[client_id client_secret]

      option :client_id, nil
      option :client_secret, nil
      option :client_options, {}
      option :authorize_params, {}
      option :authorize_options, %i[scope state]
      option :token_params, {}
      option :token_options, []
      option :auth_token_params, {}
      option :provider_ignores_state, false
      option :pkce, false
      option :pkce_options, {
        :code_challenge => proc { |verifier|
          Base64.urlsafe_encode64(
            Digest::SHA2.digest(verifier),
            :padding => false,
          )
        },
        :code_challenge_method => "S256",
      }

      attr_accessor :access_token

      def client
        ::OAuth2::Client.new(options.client_id, options.client_secret, deep_symbolize(options.client_options))
      end

      credentials do
        hash = {"token" => access_token.token} #: Hash[String, String | Integer | bool | nil]
        hash["refresh_token"] = access_token.refresh_token if access_token.expires? && access_token.refresh_token
        hash["expires_at"] = access_token.expires_at if access_token.expires?
        hash["expires"] = access_token.expires?
        hash
      end

      def request_phase
        redirect client.auth_code.authorize_url({:redirect_uri => callback_url}.merge(authorize_params))
      end

      def authorize_params
        options.authorize_params[:state] = SecureRandom.hex(24)

        if OmniAuth.config.test_mode
          test_env = (@env ||= {}) #: Rack::env
          test_env["rack.session"] ||= {}
        end

        params = options.authorize_params
                        .merge(options_for("authorize"))
                        .merge(pkce_authorize_params)

        session["omniauth.state"] = params.fetch(:state)
        # Reused in the token request, which must send the same redirect_uri.
        # oauth2 gives a client_options redirect_uri precedence in the
        # authorize URL, so it does here too.
        session["omniauth.redirect_uri"] = client.options[:redirect_uri] || params[:redirect_uri] || callback_url

        params
      end

      def token_params
        options.token_params.merge(options_for("token")).merge(pkce_token_params)
      end

      def callback_phase
        @stored_redirect_uri = session.delete("omniauth.redirect_uri")
        error = request.params["error_reason"] || request.params["error"]
        if csrf_detected?
          fail!(:csrf_detected, CallbackError.new(:csrf_detected, "CSRF detected"))
        elsif error
          fail!(error, CallbackError.new(request.params["error"], request.params["error_description"] || request.params["error_reason"], request.params["error_uri"]))
        else
          self.access_token = build_access_token
          self.access_token = access_token.refresh! if access_token.expired?
          super
        end
      rescue ::OAuth2::Error, CallbackError => e
        fail!(:invalid_credentials, e)
      rescue ::Timeout::Error, ::Errno::ETIMEDOUT, ::OAuth2::TimeoutError, ::OAuth2::ConnectionError => e
        fail!(:timeout, e)
      rescue ::SocketError => e
        fail!(:failed_to_connect, e)
      end

    protected

      # Whether the callback's state is missing or doesn't match the one the
      # request phase stored, unless the provider ignores state.
      def csrf_detected?
        return false if options.provider_ignores_state

        state = request.params["state"].to_s
        state.empty? || !secure_compare(state, session.delete("omniauth.state").to_s)
      end

      def pkce_authorize_params
        return {} unless options.pkce

        # A fresh verifier for every authorization request, as RFC 7636
        # requires: https://tools.ietf.org/html/rfc7636#section-4.1
        verifier = SecureRandom.hex(64)
        session["omniauth.pkce.verifier"] = verifier

        # NOTE: see https://tools.ietf.org/html/rfc7636#appendix-A
        {
          :code_challenge => options.pkce_options.fetch(:code_challenge).call(verifier),
          :code_challenge_method => options.pkce_options.fetch(:code_challenge_method),
        }
      end

      def pkce_token_params
        return {} unless options.pkce

        {:code_verifier => session.delete("omniauth.pkce.verifier")}
      end

      def build_access_token
        verifier = request.params["code"]
        redirect_uri = @stored_redirect_uri || session.delete("omniauth.redirect_uri") || callback_url
        client.auth_code.get_token(verifier, {:redirect_uri => redirect_uri}.merge(token_params.to_hash(:symbolize_keys => true)), deep_symbolize(options.auth_token_params))
      end

      def deep_symbolize(options)
        hash = {} #: Hash[Symbol, untyped]
        options.each { |key, value| hash[key.to_sym] = value.is_a?(Hash) ? deep_symbolize(value) : value }
        hash
      end

      def options_for(option)
        hash = {} #: Hash[Symbol, untyped]
        options.public_send(:"#{option}_options").select { |key| options[key] }.each do |key|
          hash[key.to_sym] = if options.fetch(key).respond_to?(:call)
                               options.fetch(key).call(env)
                             else
                               options.fetch(key)
                             end
        end
        hash
      end

      # constant-time comparison algorithm to prevent timing attacks
      def secure_compare(string_a, string_b)
        Rack::Utils.secure_compare(string_a, string_b)
      end

      # An error that is indicated in the OAuth 2.0 callback.
      # This could be a `redirect_uri_mismatch` or other
      class CallbackError < StandardError
        attr_accessor :error, :error_reason, :error_uri

        def initialize(error, error_reason = nil, error_uri = nil)
          self.error = error
          self.error_reason = error_reason
          self.error_uri = error_uri
        end

        def message
          [error, error_reason, error_uri].compact.join(" | ")
        end
      end
    end
  end
end

OmniAuth.config.add_camelization "oauth2", "OAuth2"
