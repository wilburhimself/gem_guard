require_relative "gem_guard/version"
require_relative "gem_guard/parser"
require_relative "gem_guard/vulnerability_fetcher"
require_relative "gem_guard/analyzer"
require_relative "gem_guard/reporter"
require_relative "gem_guard/cli"
require_relative "gem_guard/config"
require_relative "gem_guard/sbom_generator"
require_relative "gem_guard/typosquat_checker"
require_relative "gem_guard/auto_fixer"

module GemGuard
  class Error < StandardError; end
end
