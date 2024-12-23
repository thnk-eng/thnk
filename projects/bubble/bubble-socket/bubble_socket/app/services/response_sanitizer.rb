
# app/services/response_sanitizer.rb
module BubbleSocket
  module Services
    module ResponseSanitizer
      SENSITIVE_REGEX = /【\d+:\d+†source】|\[\d+\]/

      def self.sanitize(response)
        sensitive_terms = ['AI', 'model', 'GPT', 'language model', 'training']
        sensitive_terms.each do |term|
          response.gsub!(/\b#{term}\b/i, 'assistant')
        end
        response.gsub!(SENSITIVE_REGEX, '')
        response.strip
      end
    end
  end
end
