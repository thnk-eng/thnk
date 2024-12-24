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

# /lib/jm_jwt/jwt.rb
require 'json'
require 'base64'
require_relative 'algorithms'
require_relative 'claims'
require_relative 'errors'

module JmJwt
  class JWT
    def self.encode(payload, key, algorithm = 'HS256', headers = {})
      validate_algorithm(algorithm)
      validate_payload(payload)

      algorithm = algorithm.to_s.upcase
      headers = { 'typ' => 'JWT', 'alg' => algorithm }.merge(headers)

      segments = []
      segments << encode_segment(headers)
      segments << encode_segment(payload)

      signing_input = segments.join('.')
      signature = encode_signature(signing_input, key, algorithm)

      segments << signature
      segments.join('.')
    end

    def self.decode(token, key, options = {})
      raise JwtError, 'Not enough or too many segments' unless token.count('.') == 2

      header_segment, payload_segment, signature_segment = token.split('.')
      header = JSON.parse(Base64.urlsafe_decode64(header_segment))
      payload = JSON.parse(Base64.urlsafe_decode64(payload_segment))

      validate_algorithm(header['alg'])
      validate_payload(payload)

      raise JwtError, 'No algorithm supplied' unless header['alg']

      verify_signature(header_segment, payload_segment, signature_segment, key, header['alg'])
      Claims.validate_registered_claims(payload, options)

      payload
    end

  private

    def self.validate_algorithm(algorithm)
      algorithm = algorithm.to_s.upcase
      unless Algorithms::SUPPORTED_ALGORITHMS.key?(algorithm)
        raise UnsupportedAlgorithmError, "Unsupported algorithm: #{algorithm}"
      end
    end

    def self.validate_payload(payload)
      payload.keys.each do |claim|
        unless Claims::REGISTERED_CLAIMS.include?(claim.to_sym) || custom_claim?(claim)
          raise JwtError, "Invalid claim: #{claim}"
        end
      end
    end

    def self.custom_claim?(claim)
      # Allow specific custom claims that are safe and expected
      allowed_custom_claims = %w[name role email]
      allowed_custom_claims.include?(claim)
    end

    def self.encode_segment(segment)
      Base64.urlsafe_encode64(JSON.generate(segment), padding: false)
    end

    def self.encode_signature(signing_input, key, algorithm)
      signature = Algorithms.sign(algorithm, signing_input, key)
      Base64.urlsafe_encode64(signature, padding: false)
    end

    def self.verify_signature(header_segment, payload_segment, signature_segment, key, algorithm)
      signing_input = [header_segment, payload_segment].join('.')
      signature = Base64.urlsafe_decode64(signature_segment)

      unless Algorithms.verify(algorithm, signing_input, signature, key)
        raise VerificationError, 'Signature verification failed'
      end
    end
  end
end
