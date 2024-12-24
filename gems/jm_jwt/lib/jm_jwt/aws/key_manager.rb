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

# lib/jm_jwt/key_manager.rb
require 'aws-sdk-kms'

module JmJwt
  module Aws
    class KeyManager
      def initialize(key_id)
        @key_id = key_id
        @kms = Aws::KMS::Client.new
      end

      def sign(message)
        resp = @kms.sign({
                           key_id: @key_id,
                           message: message,
                           message_type: 'RAW',
                           signing_algorithm: 'RSASSA_PKCS1_V1_5_SHA_256'
                         })
        resp.signature
      end

      def verify(message, signature)
        resp = @kms.verify({
                             key_id: @key_id,
                             message: message,
                             message_type: 'RAW',
                             signature: signature,
                             signing_algorithm: 'RSASSA_PKCS1_V1_5_SHA_256'
                           })
        resp.signature_valid
      end
    end
  end
end