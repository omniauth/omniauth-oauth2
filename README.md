# OmniAuth OAuth2

[![Gem Version](http://img.shields.io/gem/v/omniauth-oauth2.svg)][gem]
[![Ruby](https://github.com/omniauth/omniauth-oauth2/actions/workflows/main.yml/badge.svg)][githubactions]
[![Maintainability](https://qlty.sh/gh/omniauth/projects/omniauth-oauth2/maintainability.svg)][qlty]
[![Coverage Status](http://img.shields.io/coveralls/omniauth/omniauth-oauth2.svg)][coveralls]
[![Duel](https://raw.githubusercontent.com/sferik/duel-ruby/main/assets/badge.svg)](https://github.com/sferik/duel-ruby)

[gem]: https://rubygems.org/gems/omniauth-oauth2
[githubactions]: https://github.com/omniauth/omniauth-oauth2/actions/workflows/main.yml
[qlty]: https://qlty.sh/gh/omniauth/projects/omniauth-oauth2
[coveralls]: https://coveralls.io/r/omniauth/omniauth-oauth2

This gem contains a generic OAuth2 strategy for OmniAuth. It is meant to serve
as a building block strategy for other strategies and not to be used
independently (since it has no inherent way to gather uid and user info).

## Creating an OAuth2 Strategy

To create an OmniAuth OAuth2 strategy using this gem, you can simply subclass
it and add a few extra methods like so:

```ruby
require 'omniauth-oauth2'

module OmniAuth
  module Strategies
    class SomeSite < OmniAuth::Strategies::OAuth2
      # Give your strategy a name.
      option :name, "some_site"

      # This is where you pass the options you would pass when
      # initializing your consumer from the OAuth gem.
      option :client_options, {:site => "https://api.somesite.com"}

      # You may specify that your strategy should use PKCE by setting
      # the pkce option to true: https://tools.ietf.org/html/rfc7636
      option :pkce, true

      # These are called after authentication has succeeded. If
      # possible, you should try to set the UID without making
      # additional calls (if the user id is returned with the token
      # or as a URI parameter). This may not be possible with all
      # providers.
      uid{ raw_info['id'] }

      info do
        {
          :name => raw_info['name'],
          :email => raw_info['email']
        }
      end

      extra do
        {
          'raw_info' => raw_info
        }
      end

      def raw_info
        @raw_info ||= access_token.get('/me').parsed
      end
    end
  end
end
```

That's pretty much it!

## Supported Ruby Versions

OmniAuth OAuth2 is tested on Ruby 2.5 through 4.0, JRuby, and TruffleRuby,
on Linux and macOS.
