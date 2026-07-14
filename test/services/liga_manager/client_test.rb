# frozen_string_literal: true

require "test_helper"

module LigaManager
  class ClientTest < ActiveSupport::TestCase
    test "unwraps {success,message,data} envelope to data" do
      VCR.use_cassette("ligamanager/seasons") do
        data = Client.new.get("seasons", "status[]" => [2, 3])
        assert_kind_of Array, data
        assert data.any?
      end
    end

    test "passes bare array response through unchanged" do
      VCR.use_cassette("ligamanager/game_types") do
        assert_kind_of Array, Client.new.get("game-types")
      end
    end

    test "raises a clear error on non-200" do
      VCR.use_cassette("ligamanager/not_found") do
        error = assert_raises(RuntimeError) { Client.new.get("this-resource-does-not-exist") }
        assert_match(/HTTP/, error.message)
      end
    end
  end
end
