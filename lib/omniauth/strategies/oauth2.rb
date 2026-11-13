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
        hash["refresh_token"] = access_token.refresh_token if access_token.refresh_token
        hash["expires_at"] = access_token.expires_at if access_token.expires?
        hash["expires"] = access_token.expires?
        hash
      end

      def request_phase
        # The provider can't do anything with an authorize request that has no
        # client ID, so fail here, where the cause is clear.
        return fail!(:missing_client_id, Error.new("client_id is missing")) if client.id.to_s.empty?

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

        state = params.fetch(:state)
        # Reused in the token request, which must send the same redirect_uri.
        # oauth2 gives a client_options redirect_uri precedence in the
        # authorize URL, so it does here too.
        redirect_uri = client.options[:redirect_uri] || params[:redirect_uri] || callback_url
        # OmniAuth stores this with the sign-in's origin and params, so the
        # callback gets all of them for its state.
        remember_sign_in(state.to_s, sign_in_data(redirect_uri))

        params
      end

      # The state the provider sends back, which OmniAuth uses to find the
      # sign-in that remember_sign_in stored.
      def callback_sign_in_key
        request.params["state"]
      end

      def token_params
        options.token_params.merge(options_for("token")).merge(pkce_token_params)
      end

      def callback_phase
        # Take what the request phase stored, even if the callback fails.
        stored_sign_in
        error = request.params["error_reason"] || request.params["error"]
        if csrf_detected?
          fail!(:csrf_detected, CallbackError.new(:csrf_detected, "CSRF detected"))
        elsif error
          fail!(error, CallbackError.new(request.params["error"], request.params["error_description"], request.params["error_uri"], :error_reason => request.params["error_reason"]))
        else
          self.access_token = fetch_access_token
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

      # Whether no sign-in is stored for the callback's state, unless the
      # provider ignores state.
      def csrf_detected?
        return false if options.provider_ignores_state

        stored_sign_in.nil?
      end

      # What the callback needs from the request phase besides OmniAuth's
      # origin and params: the redirect URI, unless it's the callback URL
      # without a query string, and the PKCE verifier. The session may be a
      # 4 KB cookie, so it stores no more than that.
      def sign_in_data(redirect_uri)
        data = {} #: sign_in
        data["redirect_uri"] = redirect_uri unless redirect_uri.eql?(callback_url_without_query)
        data["pkce_verifier"] = @pkce_verifier if options.pkce
        data
      end

      # What the request phase stored for this callback's state, removed from
      # the session, or nil if no sign-in is stored for it. OmniAuth keeps
      # it, with the sign-in's "origin" and "params".
      def stored_sign_in
        remembered_sign_in
      end

      # The redirect URI the authorize request sent, which the token request
      # must send too.
      def stored_redirect_uri
        sign_in = stored_sign_in
        return callback_url unless sign_in

        sign_in.fetch("redirect_uri") { callback_url_without_query }
      end

      # The callback URL without the current request's query string, the
      # same in the request and callback phases.
      def callback_url_without_query
        full_host + callback_path
      end

      def pkce_authorize_params
        return {} unless options.pkce

        # A fresh verifier for every authorization request, as RFC 7636
        # requires: https://tools.ietf.org/html/rfc7636#section-4.1. Its 32
        # random bytes encode to 43 characters, the shortest it allows,
        # which keeps the session small.
        verifier = @pkce_verifier = SecureRandom.urlsafe_base64(32)

        # NOTE: see https://tools.ietf.org/html/rfc7636#appendix-A
        {
          :code_challenge => options.pkce_options.fetch(:code_challenge).call(verifier),
          :code_challenge_method => options.pkce_options.fetch(:code_challenge_method),
        }
      end

      def pkce_token_params
        return {} unless options.pkce

        verifier = stored_sign_in.to_h["pkce_verifier"]
        verifier ? {:code_verifier => verifier} : {}
      end

      # The access token from the callback's code, refreshed if it's already
      # expired.
      def fetch_access_token
        token = build_access_token || raise(CallbackError.new(:invalid_credentials, "No access token"))
        token.expired? ? token.refresh! : token
      end

      def build_access_token
        verifier = request.params["code"]
        client.auth_code.get_token(verifier, {:redirect_uri => stored_redirect_uri}.merge(token_params.to_hash(:symbolize_keys => true)), deep_symbolize(options.auth_token_params))
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

      # An error that is indicated in the OAuth 2.0 callback, such as a
      # redirect_uri_mismatch, with the provider's error, error_description,
      # and error_uri params. Some providers, like Facebook, also send an
      # error_reason, such as user_denied.
      class CallbackError < StandardError
        attr_accessor :error, :error_description, :error_uri, :error_reason

        def initialize(error, error_description = nil, error_uri = nil, error_reason: nil)
          self.error = error
          self.error_description = error_description
          self.error_uri = error_uri
          self.error_reason = error_reason
        end

        def message
          [error, error_reason, error_description, error_uri].compact.join(" | ")
        end
      end
    end
  end
end

OmniAuth.config.add_camelization "oauth2", "OAuth2"
