require_relative "lib/tokenizers/version"

Gem::Specification.new do |spec|
  spec.name          = "tokenizers"
  spec.version       = Tokenizers::VERSION
  spec.summary       = "Fast state-of-the-art tokenizers for Ruby"
  spec.homepage      = ""
  spec.license       = ""

  spec.author        = ""
  spec.email         = ""

  spec.files         = Dir["*.{md,txt}", "{ext,lib}/**/*", "Cargo.*"]
  spec.require_path  = "lib"
  spec.extensions    = ["ext/tokenizers/extconf.rb"]

  spec.required_ruby_version = ">= 3.1"

  spec.add_dependency "rb_sys"
end
