# frozen_string_literal: true

require "test_helper"

# Carambus.ssl_verify_mode ist die einzige Quelle fuer den TLS-Verify-Modus aller
# ausgehenden HTTPS-Aufrufe (ClubCloud, Authority-Sync, Auth0, Kozoom, SoopLive).
# Vorher stand an 15 Stellen unbedingt VERIFY_NONE — auch in production.
class SslVerifyModeTest < ActiveSupport::TestCase
  setup do
    @original = ENV["CARAMBUS_TLS_INSECURE"]
  end

  teardown do
    if @original.nil?
      ENV.delete("CARAMBUS_TLS_INSECURE")
    else
      ENV["CARAMBUS_TLS_INSECURE"] = @original
    end
  end

  test "prueft Zertifikate per Default" do
    ENV.delete("CARAMBUS_TLS_INSECURE")
    assert_equal OpenSSL::SSL::VERIFY_PEER, Carambus.ssl_verify_mode
  end

  test "Notausstieg CARAMBUS_TLS_INSECURE=1 schaltet die Pruefung ab" do
    ENV["CARAMBUS_TLS_INSECURE"] = "1"
    assert_equal OpenSSL::SSL::VERIFY_NONE, Carambus.ssl_verify_mode
  end

  test "nur exakt 1 oeffnet den Notausstieg — kein versehentliches Abschalten" do
    ["0", "", "true", "yes", "false"].each do |value|
      ENV["CARAMBUS_TLS_INSECURE"] = value
      assert_equal OpenSSL::SSL::VERIFY_PEER, Carambus.ssl_verify_mode,
        "CARAMBUS_TLS_INSECURE=#{value.inspect} darf die Pruefung NICHT abschalten"
    end
  end

  # Waechter gegen Rueckfall: neue Netzwerkaufrufe sollen den Helper nutzen statt
  # wieder ein hartes VERIFY_NONE einzubauen. Zwei Alt-Stellen sind bewusst
  # ausgenommen — sie gaten bereits selbst per Rails.env.
  test "kein unbedingtes VERIFY_NONE in app/" do
    erlaubt = %w[
      app/services/umb/http_client.rb
      app/services/sooplive_billiards_client.rb
    ]

    treffer = Dir.glob(Rails.root.join("app/**/*.rb")).filter_map do |path|
      relativ = Pathname.new(path).relative_path_from(Rails.root).to_s
      next if erlaubt.include?(relativ)

      zeilen = File.readlines(path).each_with_index.select do |line, _i|
        line.include?("VERIFY_NONE") && !line.strip.start_with?("#")
      end
      next if zeilen.empty?

      "#{relativ}: #{zeilen.map { |_l, i| i + 1 }.join(", ")}"
    end

    assert_empty treffer,
      "Unbedingtes VERIFY_NONE gefunden — bitte Carambus.ssl_verify_mode verwenden:\n#{treffer.join("\n")}"
  end
end
