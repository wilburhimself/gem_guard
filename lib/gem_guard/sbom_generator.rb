require "json"
require "digest"
require "time"

module GemGuard
  class SbomGenerator
    SPDX_VERSION = "SPDX-2.3"
    CYCLONE_DX_VERSION = "1.5"

    def initialize
      @document_id = "SPDXRef-DOCUMENT"
      @creation_time = Time.now.utc.iso8601
    end

    def generate_spdx(dependencies, project_name = "ruby-project")
      {
        "spdxVersion" => SPDX_VERSION,
        "dataLicense" => "CC0-1.0",
        "SPDXID" => @document_id,
        "name" => "#{project_name}-sbom",
        "documentNamespace" => "https://gem-guard.dev/#{project_name}/#{@creation_time}",
        "creationInfo" => {
          "created" => @creation_time,
          "creators" => ["Tool: gem_guard-#{GemGuard::VERSION}"],
          "licenseListVersion" => "3.21"
        },
        "packages" => build_spdx_packages(dependencies, project_name),
        "relationships" => build_spdx_relationships(dependencies)
      }
    end

    def generate_cyclone_dx(dependencies, project_name = "ruby-project")
      {
        "bomFormat" => "CycloneDX",
        "specVersion" => CYCLONE_DX_VERSION,
        "serialNumber" => "urn:uuid:#{generate_uuid}",
        "version" => 1,
        "metadata" => {
          "timestamp" => @creation_time,
          "tools" => [
            {
              "vendor" => "GemGuard",
              "name" => "gem_guard",
              "version" => GemGuard::VERSION
            }
          ],
          "component" => {
            "type" => "application",
            "name" => project_name,
            "version" => "1.0.0"
          }
        },
        "components" => build_cyclone_dx_components(dependencies)
      }
    end

    private

    def build_spdx_packages(dependencies, project_name)
      packages = []

      # Add root package
      packages << {
        "SPDXID" => "SPDXRef-Package-#{sanitize_name(project_name)}",
        "name" => project_name,
        "downloadLocation" => "NOASSERTION",
        "filesAnalyzed" => false,
        "copyrightText" => "NOASSERTION"
      }

      # Add dependency packages
      dependencies.each_with_index do |dep, index|
        packages << {
          "SPDXID" => "SPDXRef-Package-#{sanitize_name(dep.name)}",
          "name" => dep.name,
          "versionInfo" => dep.version,
          "downloadLocation" => gem_download_url(dep.name, dep.version),
          "filesAnalyzed" => false,
          "homepage" => gem_homepage_url(dep.name),
          "copyrightText" => "NOASSERTION",
          "externalRefs" => [
            {
              "referenceCategory" => "PACKAGE-MANAGER",
              "referenceType" => "purl",
              "referenceLocator" => "pkg:gem/#{dep.name}@#{dep.version}"
            }
          ]
        }
      end

      packages
    end

    def build_spdx_relationships(dependencies)
      relationships = []

      dependencies.each do |dep|
        relationships << {
          "spdxElementId" => @document_id,
          "relationshipType" => "DESCRIBES",
          "relatedSpdxElement" => "SPDXRef-Package-#{sanitize_name(dep.name)}"
        }
      end

      relationships
    end

    def build_cyclone_dx_components(dependencies)
      dependencies.map do |dep|
        {
          "type" => "library",
          "bom-ref" => "pkg:gem/#{dep.name}@#{dep.version}",
          "name" => dep.name,
          "version" => dep.version,
          "purl" => "pkg:gem/#{dep.name}@#{dep.version}",
          "externalReferences" => [
            {
              "type" => "distribution",
              "url" => gem_download_url(dep.name, dep.version)
            },
            {
              "type" => "website",
              "url" => gem_homepage_url(dep.name)
            }
          ]
        }
      end
    end

    def sanitize_name(name)
      name.gsub(/[^a-zA-Z0-9\-_]/, "-")
    end

    def gem_download_url(name, version)
      "https://rubygems.org/downloads/#{name}-#{version}.gem"
    end

    def gem_homepage_url(name)
      "https://rubygems.org/gems/#{name}"
    end

    def generate_uuid
      # Simple UUID v4 generation
      bytes = Array.new(16) { rand(256) }
      bytes[6] = (bytes[6] & 0x0f) | 0x40  # Version 4
      bytes[8] = (bytes[8] & 0x3f) | 0x80  # Variant bits
      
      format = "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x"
      format % bytes
    end
  end
end
