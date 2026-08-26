# © 2026 aiaiaiai · aiaiaiai.org

require_relative "lib/prism_bot/version"

Gem::Specification.new do |spec|
  spec.name = "aiaiaiai-prism-bot"
  spec.version = PrismBot::VERSION
  spec.authors = ["aiaiaiai"]
  spec.email = ["engineering@aiaiaiai.org"]
  spec.summary = "Modular messaging surfaces for the Prism Hub API"
  spec.homepage = "https://github.com/aiaiaiai-org/prism-bot"
  spec.required_ruby_version = Gem::Requirement.new(">= 4.0", "< 4.1")
  spec.files = Dir[
    "config.ru",
    "config/**/*",
    "contracts/**/*",
    "lib/**/*",
    "README.md"
  ]
  spec.require_paths = ["lib"]

  spec.add_dependency "puma", ">= 6.6"
  spec.add_dependency "rack", "~> 3.2"
  spec.add_dependency "rackup", "~> 2.2"

  spec.add_development_dependency "bundler-audit"
  spec.add_development_dependency "minitest", "~> 5.25"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rubocop-rails-omakase"
end
