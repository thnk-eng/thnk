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

module JmJwt
  module Claims
    REGISTERED_CLAIMS = [:iss, :sub, :aud, :exp, :nbf, :iat, :jti]

    def self.validate_registered_claims(payload, options)
      validate_expiration(payload, options)
      validate_not_before(payload, options)
      validate_issuer(payload, options)
      validate_audience(payload, options)
      validate_subject(payload, options)
      validate_jti(payload, options)
    end

    def self.validate_expiration(payload, options)
      if options[:verify_expiration] && payload['exp']
        raise ExpiredSignatureError, 'Token has expired' if payload['exp'] < Time.now.to_i
      end
    end

    def self.validate_not_before(payload, options)
      if options[:verify_not_before] && payload['nbf']
        raise ImmatureSignatureError, 'Token not yet valid' if payload['nbf'] > Time.now.to_i
      end
    end

    def self.validate_issuer(payload, options)
      if options[:iss]
        raise InvalidIssuerError, 'Invalid issuer' unless payload['iss'] == options[:iss]
      end
    end

    def self.validate_audience(payload, options)
      if options[:aud]
        aud = Array(options[:aud])
        raise InvalidAudienceError, 'Invalid audience' unless (Array(payload['aud']) & aud).any?
      end
    end

    def self.validate_subject(payload, options)
      if options[:sub]
        raise InvalidSubjectError, 'Invalid subject' unless payload['sub'] == options[:sub]
      end
    end

    def self.validate_jti(payload, options)
      if options[:verify_jti]
        raise InvalidJtiError, 'Missing jti' unless payload['jti']
      end
    end
  end
end
