# frozen_string_literal: true

require "test_helper"

# Seitenausschnitte im Format von ndbv.de (2026-11-24): cbdet.php / cbmemdet.php per POST.
class ClubCloudPublicClientTest < ActiveSupport::TestCase
  LIST = <<~HTML
    <article><section><table class="silver">
      <tr><td><a href="#" onclick="return cp(0,1001)" title="1. BC Schwerin" class="cc_bluelink">1. BC Schwerin</a><br>Ziegeleiweg 9-11</td></tr>
      <tr><td><a href="#" onclick="return cp(0,1002)" title="1. BU Flensburg" class="cc_bluelink">1. BU Flensburg</a></td></tr>
      <tr><td><a href="#" onclick="return cp(0,1001)" title="1. BC Schwerin">doppelt</a></td></tr>
    </table></section></article>
    <a href="#" onclick='return clubNavigate("cbtea.php",{})'>Mannschaften</a>
    <a href='#' onClick='return cp(0,0)' title='Alle Sparten' class='cc_white'>Alle Sparten</a>
    <a href='#' onClick='return cp(1,0)' title='Pool' class='cc_white'>Pool</a>
  HTML

  DETAILS = <<~HTML
    <aside><section><table class="silver">
      <tr><td>Verband</td><td>Norddeutscher Billard-Verband e.V. (NBV)</td></tr>
      <tr><td>Verein</td><td>1. Billard-Club Schwerin e.V.</td></tr>
      <tr><td>DBU-Nr.</td><td>2191</td></tr>
    </table></section></aside>
  HTML

  MEMBERS = <<~HTML
    <article><section><table class="silver">
      <tr><td><a href='#' onClick='return memberPage(11928)' title='Bui, Van Minh' class='cc_bluelink'><strong>Bui, Van Minh</strong></a><br>Pass-Nr.: 11928</td></tr>
      <tr><td><a href='#' onClick='return memberPage(11628)' title='Cronin, Chris' class='cc_bluelink'>Cronin, Chris</a></td></tr>
    </table></section></article>
  HTML

  MEMBER = <<~HTML
    <aside><section>
      <table class="silver"><tr><td>Verein</td><td>1. Billard-Club Schwerin e.V.</td></tr></table>
      <table class="silver"><tr><td>Name</td><td>Van Minh Bui</td></tr><tr><td>Pass-Nr.</td><td>11928</td></tr><tr><td>DBU-Nr.</td><td>403662</td></tr></table>
    </section></aside>
  HTML

  # pages: [Seite, a, m] => HTML; codes: Folge von HTTP-Codes je Aufruf (Standard 200).
  def client(pages, codes: [], sleeps: [], clock: -> { 0.0 })
    @calls = []
    http = lambda do |uri, params|
      @calls << [uri.to_s, params]
      [codes.shift || "200", pages.fetch([File.basename(uri.path), params[:a], params[:m]], "")]
    end
    ClubCloudPublicClient.new(base_url: "https://ndbv.de", fed_id: 20, http: http, sleeper: ->(s) { sleeps << s }, clock: clock)
  end

  test "Vereinsliste per POST: cc_id und Kurzname aus cp(0,…), ohne Dubletten, Navigations- und Sparten-Links" do
    c = client({["cbdet.php", nil, nil] => LIST})

    assert_equal [[1001, "1. BC Schwerin"], [1002, "1. BU Flensburg"]], c.clubs
    uri, params = @calls.first
    assert_equal "https://ndbv.de/cbdet.php", uri
    assert_equal 20, params[:f]
    assert_equal ClubCloudPublicClient::ALL, params[:eps]
  end

  test "Vereinsdetails, Mitgliederliste und Spielerdetails" do
    c = client({["cbdet.php", 1001, nil] => DETAILS, ["cbmemdet.php", 1001, 0] => MEMBERS, ["cbmemdet.php", 1001, 11928] => MEMBER})

    details = ClubCloudPublicClient.details(c.club_doc(1001).css("aside table.silver")[0])
    assert_equal "2191", details["DBU-Nr."].text
    members = ClubCloudPublicClient.members(c.members_doc(1001))
    assert_equal [[11928, "Bui, Van Minh"], [11628, "Cronin, Chris"]], members.map { |m| [m.pass_nr, m.name] }
    info = ClubCloudPublicClient.details(c.member_doc(1001, 11928).css("aside table.silver")[1])
    assert_equal "403662", info["DBU-Nr."].text
    assert_equal "Van Minh Bui", info["Name"].text
  end

  test "HTTP 429: Pause und Wiederholung, dann Erfolg" do
    sleeps = []
    c = client({["cbdet.php", nil, nil] => LIST}, codes: %w[429 429 200], sleeps: sleeps, clock: -> { 1000.0 })

    assert_equal 2, c.clubs.size
    assert_equal 3, @calls.size
    assert_equal 2, sleeps.count(ClubCloudPublicClient::PAUSE_SECONDS)
  end

  test "Fehler statt leerer Seite: 429 nach allen Wiederholungen oder anderer HTTP-Code" do
    c = client({}, codes: ["429"] * (ClubCloudPublicClient::RETRIES + 1))
    assert_raises(ClubCloudPublicClient::Error) { c.clubs }

    assert_raises(ClubCloudPublicClient::Error) { client({}, codes: %w[410]).club_doc(1) }
  end

  test "Mindestabstand zwischen zwei Anfragen" do
    sleeps = []
    now = 10.0
    c = client({["cbdet.php", 1, nil] => DETAILS}, sleeps: sleeps, clock: -> { now })
    c.club_doc(1)
    now += 0.2
    c.club_doc(1)

    assert_in_delta ClubCloudPublicClient::MIN_INTERVAL - 0.2, sleeps.sum, 0.001
  end

  test "url_for nur als Herkunftsangabe" do
    assert_equal "https://ndbv.de/cbmemdet.php?a=1001&f=20&m=7", client({}).url_for("cbmemdet.php", a: 1001, m: 7)
  end
end
