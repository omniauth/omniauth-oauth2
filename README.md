# OmniAuth OAuth2

This gem contains a generic OAuth2 strategy for OmniAuth. It is meant to
serve as a building block strategy for other strategies and not to be
used independently (since it has no inherent way to gather uid and user
info).

## Creating an OAuth2 Strategy

To create an OmniAuth OAuth2 strategy using this gem, you can simply
subclass it and add a few extra methods like so:

    require 'omniauth-oauth2'

    module OmniAuth
      module Strategies
        class SomeSite < OmniAuth::Strategies::OAuth2
          # Give your strategy a name.
          option :name, "some_site"

          # This is where you pass the options you would pass when
          # initializing your consumer from the OAuth gem.
          option :client_options, {:site => "https://api.somesite.com"}

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

That's pretty much it!

## License

Copyright (C) 2011 by Michael Bleigh and Intridea, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
