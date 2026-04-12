# frozen_string_literal: true

require "test_helper"

class Umb::HttpClientTest < ActiveSupport::TestCase
  setup do
    @client = Umb::HttpClient.new
  end

  # --- ssl_verify_mode ---

  test "ssl_verify_mode returns VERIFY_NONE in test environment" do
    assert_equal OpenSSL::SSL::VERIFY_NONE, Umb::HttpClient.ssl_verify_mode
  end

  test "ssl_verify_mode returns VERIFY_PEER in production environment" do
    Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("production")) do
      assert_equal OpenSSL::SSL::VERIFY_PEER, Umb::HttpClient.ssl_verify_mode
    end
  end

  test "ssl_verify_mode returns VERIFY_NONE in development environment" do
    Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("development")) do
      assert_equal OpenSSL::SSL::VERIFY_NONE, Umb::HttpClient.ssl_verify_mode
    end
  end

  # --- fetch_url ---

  test "fetch_url returns body on HTTP 200" do
    stub_request(:get, "https://example.com/page")
      .to_return(status: 200, body: "<html>content</html>", headers: {})

    result = @client.fetch_url("https://example.com/page")
    assert_equal "<html>content</html>", result
  end

  test "fetch_url returns nil on HTTP 500" do
    stub_request(:get, "https://example.com/error")
      .to_return(status: 500, body: "Internal Server Error", headers: {})

    result = @client.fetch_url("https://example.com/error")
    assert_nil result
  end

  test "fetch_url returns nil on HTTP 404" do
    stub_request(:get, "https://example.com/missing")
      .to_return(status: 404, body: "Not Found", headers: {})

    result = @client.fetch_url("https://example.com/missing")
    assert_nil result
  end

  test "fetch_url follows redirects" do
    stub_request(:get, "https://example.com/old")
      .to_return(status: 301, headers: { "Location" => "https://example.com/new" })
    stub_request(:get, "https://example.com/new")
      .to_return(status: 200, body: "new page", headers: {})

    result = @client.fetch_url("https://example.com/old")
    assert_equal "new page", result
  end

  test "fetch_url returns nil when max redirects exceeded" do
    stub_request(:get, "https://example.com/loop")
      .to_return(status: 301, headers: { "Location" => "https://example.com/loop" })

    result = @client.fetch_url("https://example.com/loop", max_redirects: 3)
    assert_nil result
  end

  test "fetch_url returns nil when follow_redirects is false" do
    stub_request(:get, "https://example.com/redirect")
      .to_return(status: 301, headers: { "Location" => "https://example.com/dest" })

    result = @client.fetch_url("https://example.com/redirect", follow_redirects: false)
    assert_nil result
  end

  test "fetch_url returns nil on network error" do
    stub_request(:get, "https://example.com/broken")
      .to_raise(SocketError.new("Failed to open TCP connection"))

    result = @client.fetch_url("https://example.com/broken")
    assert_nil result
  end

  test "fetch_url returns nil on timeout" do
    stub_request(:get, "https://example.com/slow")
      .to_raise(Net::ReadTimeout)

    result = @client.fetch_url("https://example.com/slow")
    assert_nil result
  end
end
