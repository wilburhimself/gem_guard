require_relative "gem_guard/version"
require_relative "gem_guard/parser"
require_relative "gem_guard/vulnerability_fetcher"
require_relative "gem_guard/analyzer"
require_relative "gem_guard/reporter"
require_relative "gem_guard/sbom_generator"
require_relative "gem_guard/cli"

module GemGuard
  class Error < StandardError; end
end
