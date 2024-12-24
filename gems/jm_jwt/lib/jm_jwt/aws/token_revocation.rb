# Copyright (c) 2024 Thnk
# Author: J
#
# All rights reserved. This software and associated documentation files (the "Software")
# may not be used, copied, modified, merged, published, distributed, sublicensed, and/or
# sold, except with the express written permission of Thnker. Unauthorized copying of this
# file, via any medium is strictly prohibited.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
# FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

# lib/jm_jwt/token_revocation.rb
require 'redis'

module JmJwt
  module Aws
    class TokenRevocation
      def initialize(redis_url)
        @redis = Redis.new(url: redis_url)
      end

      def revoke(jti, exp)
        @redis.set("revoked:#{jti}", 1, ex: exp)
      end

      def revoked?(jti)
        @redis.exists?("revoked:#{jti}")
      end
    end
  end
end