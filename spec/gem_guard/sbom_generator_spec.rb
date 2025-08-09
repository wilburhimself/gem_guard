require "spec_helper"

RSpec.describe GemGuard::SbomGenerator do
  let(:generator) { described_class.new }
  let(:dependencies) do
    [
      GemGuard::Dependency.new(name: "rails", version: "7.0.0", source: "rubygems"),
      GemGuard::Dependency.new(name: "rack", version: "2.2.3", source: "rubygems")
    ]
  end

  describe "#generate_spdx" do
    let(:spdx_output) { generator.generate_spdx(dependencies, "test-project") }

    it "generates valid SPDX structure" do
      expect(spdx_output).to include("spdxVersion" => "SPDX-2.3")
      expect(spdx_output).to include("dataLicense" => "CC0-1.0")
      expect(spdx_output).to include("SPDXID" => "SPDXRef-DOCUMENT")
      expect(spdx_output).to include("name" => "test-project-sbom")
    end

    it "includes creation info with tool information" do
      creation_info = spdx_output["creationInfo"]
      expect(creation_info).to include("creators")
      expect(creation_info["creators"]).to include("Tool: gem_guard-#{GemGuard::VERSION}")
      expect(creation_info).to have_key("created")
    end

    it "includes packages for all dependencies" do
      packages = spdx_output["packages"]
      expect(packages).to be_an(Array)
      expect(packages.length).to eq(3) # root package + 2 dependencies

      # Check root package
      root_package = packages.find { |pkg| pkg["name"] == "test-project" }
      expect(root_package).not_to be_nil
      expect(root_package["SPDXID"]).to eq("SPDXRef-Package-test-project")

      # Check dependency packages
      rails_package = packages.find { |pkg| pkg["name"] == "rails" }
      expect(rails_package).not_to be_nil
      expect(rails_package["versionInfo"]).to eq("7.0.0")
      expect(rails_package["downloadLocation"]).to eq("https://rubygems.org/downloads/rails-7.0.0.gem")

      rack_package = packages.find { |pkg| pkg["name"] == "rack" }
      expect(rack_package).not_to be_nil
      expect(rack_package["versionInfo"]).to eq("2.2.3")
    end

    it "includes external references with purl" do
      packages = spdx_output["packages"]
      rails_package = packages.find { |pkg| pkg["name"] == "rails" }

      expect(rails_package["externalRefs"]).to be_an(Array)
      purl_ref = rails_package["externalRefs"].find { |ref| ref["referenceType"] == "purl" }
      expect(purl_ref["referenceLocator"]).to eq("pkg:gem/rails@7.0.0")
    end

    it "includes relationships" do
      relationships = spdx_output["relationships"]
      expect(relationships).to be_an(Array)
      expect(relationships.length).to eq(2) # one for each dependency

      relationships.each do |rel|
        expect(rel["spdxElementId"]).to eq("SPDXRef-DOCUMENT")
        expect(rel["relationshipType"]).to eq("DESCRIBES")
      end
    end
  end

  describe "#generate_cyclone_dx" do
    let(:cyclone_dx_output) { generator.generate_cyclone_dx(dependencies, "test-project") }

    it "generates valid CycloneDX structure" do
      expect(cyclone_dx_output).to include("bomFormat" => "CycloneDX")
      expect(cyclone_dx_output).to include("specVersion" => "1.5")
      expect(cyclone_dx_output).to include("version" => 1)
      expect(cyclone_dx_output).to have_key("serialNumber")
    end

    it "includes metadata with tool information" do
      metadata = cyclone_dx_output["metadata"]
      expect(metadata).to have_key("timestamp")
      expect(metadata["tools"]).to be_an(Array)

      tool = metadata["tools"].first
      expect(tool["name"]).to eq("gem_guard")
      expect(tool["version"]).to eq(GemGuard::VERSION)
    end

    it "includes component metadata for the project" do
      component = cyclone_dx_output["metadata"]["component"]
      expect(component["type"]).to eq("application")
      expect(component["name"]).to eq("test-project")
      expect(component["version"]).to eq("1.0.0")
    end

    it "includes components for all dependencies" do
      components = cyclone_dx_output["components"]
      expect(components).to be_an(Array)
      expect(components.length).to eq(2)

      rails_component = components.find { |comp| comp["name"] == "rails" }
      expect(rails_component).not_to be_nil
      expect(rails_component["type"]).to eq("library")
      expect(rails_component["version"]).to eq("7.0.0")
      expect(rails_component["purl"]).to eq("pkg:gem/rails@7.0.0")

      rack_component = components.find { |comp| comp["name"] == "rack" }
      expect(rack_component).not_to be_nil
      expect(rack_component["version"]).to eq("2.2.3")
    end

    it "includes external references for each component" do
      components = cyclone_dx_output["components"]
      rails_component = components.find { |comp| comp["name"] == "rails" }

      external_refs = rails_component["externalReferences"]
      expect(external_refs).to be_an(Array)

      distribution_ref = external_refs.find { |ref| ref["type"] == "distribution" }
      expect(distribution_ref["url"]).to eq("https://rubygems.org/downloads/rails-7.0.0.gem")

      website_ref = external_refs.find { |ref| ref["type"] == "website" }
      expect(website_ref["url"]).to eq("https://rubygems.org/gems/rails")
    end

    it "generates valid UUID for serialNumber" do
      serial_number = cyclone_dx_output["serialNumber"]
      expect(serial_number).to match(/^urn:uuid:[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/)
    end
  end

  describe "private methods" do
    describe "#sanitize_name" do
      it "replaces invalid characters with hyphens" do
        sanitized = generator.send(:sanitize_name, "test@name.with/special")
        expect(sanitized).to eq("test-name-with-special")
      end

      it "preserves valid characters" do
        sanitized = generator.send(:sanitize_name, "valid-name_123")
        expect(sanitized).to eq("valid-name_123")
      end
    end

    describe "#gem_download_url" do
      it "generates correct RubyGems download URL" do
        url = generator.send(:gem_download_url, "rails", "7.0.0")
        expect(url).to eq("https://rubygems.org/downloads/rails-7.0.0.gem")
      end
    end

    describe "#gem_homepage_url" do
      it "generates correct RubyGems homepage URL" do
        url = generator.send(:gem_homepage_url, "rails")
        expect(url).to eq("https://rubygems.org/gems/rails")
      end
    end

    describe "#generate_uuid" do
      it "generates valid UUID v4" do
        uuid = generator.send(:generate_uuid)
        expect(uuid).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/)
      end

      it "generates unique UUIDs" do
        uuid1 = generator.send(:generate_uuid)
        uuid2 = generator.send(:generate_uuid)
        expect(uuid1).not_to eq(uuid2)
      end
    end
  end
end
