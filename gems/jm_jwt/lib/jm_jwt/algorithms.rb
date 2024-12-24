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

require 'openssl'

module JmJwt
  module Algorithms
    SUPPORTED_ALGORITHMS = {
      'HS256' => ['sha256', :hmac],
      'HS384' => ['sha384', :hmac],
      'HS512' => ['sha512', :hmac],
      'RS256' => ['sha256', :rsa],
      'RS384' => ['sha384', :rsa],
      'RS512' => ['sha512', :rsa],
      'ES256' => ['sha256', :ecdsa],
      'ES384' => ['sha384', :ecdsa],
      'ES512' => ['sha512', :ecdsa]
    }

    def self.sign(algorithm, msg, key)
      digest, algo_type = SUPPORTED_ALGORITHMS[algorithm]
      raise UnsupportedAlgorithmError, "Unsupported algorithm: #{algorithm}" unless digest

      case algo_type
        when :hmac
          OpenSSL::HMAC.digest(digest, key, msg)
        when :rsa
          raise InvalidKeyError, "Invalid RSA key" unless key.is_a?(OpenSSL::PKey::RSA)
          key.sign(OpenSSL::Digest.new(digest), msg)
        when :ecdsa
          raise InvalidKeyError, "Invalid ECDSA key" unless key.is_a?(OpenSSL::PKey::EC)
          key.dsa_sign_asn1(OpenSSL::Digest.new(digest).digest(msg))
        else
          raise UnsupportedAlgorithmError, "Unsupported algorithm type: #{algo_type}"
      end
    end

    def self.verify(algorithm, msg, signature, key)
      digest, algo_type = SUPPORTED_ALGORITHMS[algorithm]
      raise UnsupportedAlgorithmError, "Unsupported algorithm: #{algorithm}" unless digest

      case algo_type
        when :hmac
          secure_compare(signature, sign(algorithm, msg, key))
        when :rsa
          raise InvalidKeyError, "Invalid RSA key" unless key.is_a?(OpenSSL::PKey::RSA)
          key.verify(OpenSSL::Digest.new(digest), signature, msg)
        when :ecdsa
          raise InvalidKeyError, "Invalid ECDSA key" unless key.is_a?(OpenSSL::PKey::EC)
          key.dsa_verify_asn1(OpenSSL::Digest.new(digest).digest(msg), signature)
        else
          raise UnsupportedAlgorithmError, "Unsupported algorithm type: #{algo_type}"
      end
    end

    def self.secure_compare(a, b)
      return false if a.bytesize != b.bytesize
      l = a.unpack "C#{a.bytesize}"
      res = 0
      b.each_byte { |byte| res |= byte ^ l.shift }
      res == 0
    end
  end
end
