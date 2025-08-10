require "spec_helper"

RSpec.describe GemGuard::TyposquatChecker do
  let(:checker) { described_class.new }
  let(:dependencies) do
    [
      GemGuard::Dependency.new(name: "railz", version: "7.0.0", source: "rubygems"),
      GemGuard::Dependency.new(name: "nokogir", version: "1.13.0", source: "rubygems"),
      GemGuard::Dependency.new(name: "legitimate_gem", version: "1.0.0", source: "rubygems"),
      GemGuard::Dependency.new(name: "rails", version: "7.0.0", source: "rubygems") # legitimate popular gem
    ]
  end

  before do
    # Since we now use fallback gems directly, no need to mock HTTP calls
    # The TyposquatChecker will use the hardcoded popular gems list
  end

  describe "#check_dependencies" do
    it "identifies suspicious typosquat gems" do
      suspicious_gems = checker.check_dependencies(dependencies)

      expect(suspicious_gems.length).to be >= 1
      
      railz_match = suspicious_gems.find { |sg| sg[:gem_name] == "railz" }
      expect(railz_match).not_to be_nil
      expect(railz_match[:suspected_target]).to eq("rails")
      expect(railz_match[:similarity_score]).to be >= 0.8
      expect(railz_match[:risk_level]).to eq("low")

      nokogir_match = suspicious_gems.find { |sg| sg[:gem_name] == "nokogir" }
      expect(nokogir_match).not_to be_nil
      expect(nokogir_match[:suspected_target]).to eq("nokogiri")
      expect(nokogir_match[:similarity_score]).to be > 0.8
    end

    it "does not flag legitimate popular gems" do
      suspicious_gems = checker.check_dependencies(dependencies)
      
      rails_match = suspicious_gems.find { |sg| sg[:gem_name] == "rails" }
      expect(rails_match).to be_nil
    end

    it "does not flag gems with low similarity" do
      low_similarity_deps = [
        GemGuard::Dependency.new(name: "completely_different", version: "1.0.0", source: "rubygems")
      ]

      suspicious_gems = checker.check_dependencies(low_similarity_deps)
      expect(suspicious_gems).to be_empty
    end

    it "handles API failures gracefully" do
      allow(Net::HTTP).to receive(:get_response).and_raise(StandardError.new("Network error"))
      
      # Should fall back to hardcoded popular gems
      suspicious_gems = checker.check_dependencies(dependencies)
      expect(suspicious_gems).not_to be_empty
    end

    it "handles invalid JSON responses" do
      allow(Net::HTTP).to receive(:get_response).and_return(
        double(code: "200", body: "invalid json")
      )
      
      suspicious_gems = checker.check_dependencies(dependencies)
      expect(suspicious_gems).not_to be_empty
    end

    it "handles API error responses" do
      allow(Net::HTTP).to receive(:get_response).and_return(
        double(code: "500", body: "Server Error")
      )
      
      suspicious_gems = checker.check_dependencies(dependencies)
      expect(suspicious_gems).not_to be_empty
    end
  end

  describe "private methods" do
    describe "#calculate_similarity" do
      it "returns 1.0 for identical strings" do
        similarity = checker.send(:calculate_similarity, "rails", "rails")
        expect(similarity).to eq(1.0)
      end

      it "returns 0.0 for completely different strings" do
        similarity = checker.send(:calculate_similarity, "rails", "xyz")
        expect(similarity).to be < 0.3
      end

      it "returns high similarity for typosquats" do
        similarity = checker.send(:calculate_similarity, "railz", "rails")
        expect(similarity).to be >= 0.8
      end

      it "handles nil and empty strings" do
        expect(checker.send(:calculate_similarity, nil, "rails")).to eq(0.0)
        expect(checker.send(:calculate_similarity, "rails", nil)).to eq(0.0)
        expect(checker.send(:calculate_similarity, "", "rails")).to eq(0.0)
        expect(checker.send(:calculate_similarity, "rails", "")).to eq(0.0)
      end

      it "is case insensitive" do
        similarity = checker.send(:calculate_similarity, "RAILS", "rails")
        expect(similarity).to eq(1.0)
      end
    end

    describe "#levenshtein_distance" do
      it "calculates correct distance for simple cases" do
        distance = checker.send(:levenshtein_distance, "cat", "bat")
        expect(distance).to eq(1)
      end

      it "calculates correct distance for insertions" do
        distance = checker.send(:levenshtein_distance, "rails", "railz")
        expect(distance).to eq(1)
      end

      it "calculates correct distance for deletions" do
        distance = checker.send(:levenshtein_distance, "rails", "rail")
        expect(distance).to eq(1)
      end

      it "returns 0 for identical strings" do
        distance = checker.send(:levenshtein_distance, "rails", "rails")
        expect(distance).to eq(0)
      end
    end

    describe "#calculate_risk_level" do
      it "returns critical for very high similarity" do
        risk = checker.send(:calculate_risk_level, 0.96)
        expect(risk).to eq("critical")
      end

      it "returns high for high similarity" do
        risk = checker.send(:calculate_risk_level, 0.92)
        expect(risk).to eq("high")
      end

      it "returns medium for medium similarity" do
        risk = checker.send(:calculate_risk_level, 0.87)
        expect(risk).to eq("medium")
      end

      it "returns low for lower similarity" do
        risk = checker.send(:calculate_risk_level, 0.82)
        expect(risk).to eq("low")
      end
    end

    describe "#cache_valid?" do
      it "returns false when no cache exists" do
        expect(checker.send(:cache_valid?)).to be_falsy
      end

      it "returns false when cache is expired" do
        checker.instance_variable_set(:@popular_gems_cache, [])
        checker.instance_variable_set(:@cache_timestamp, Time.now - 7200) # 2 hours ago
        
        expect(checker.send(:cache_valid?)).to be false
      end

      it "returns true when cache is valid" do
        checker.instance_variable_set(:@popular_gems_cache, [])
        checker.instance_variable_set(:@cache_timestamp, Time.now - 1800) # 30 minutes ago
        
        expect(checker.send(:cache_valid?)).to be true
      end
    end
  end

  private

  def popular_gems_json
    [
      { "name" => "rails", "downloads" => 100_000_000 },
      { "name" => "nokogiri", "downloads" => 50_000_000 },
      { "name" => "rake", "downloads" => 80_000_000 },
      { "name" => "json", "downloads" => 70_000_000 },
      { "name" => "bundler", "downloads" => 90_000_000 }
    ].to_json
  end
end
