# frozen_string_literal: true

require "test_helper"

# 2026-06-20: Region->Verein-Stufe der Player-Cascade fuer Server OHNE Region-Context
# (carambus.de, Authority). Das system_admin?-Gate ist Pflicht — sonst Vereins-Listen-Leak.
class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  test "clubs_by_region: ohne system_admin -> forbidden" do
    sign_in users(:player)
    get clubs_by_region_admin_users_path, params: {region_id: regions(:nbv).id}
    assert_response :forbidden
  end

  test "clubs_by_region: system_admin bekommt benannte Vereine der Region als JSON" do
    clubs(:bcw).update!(region: regions(:nbv))
    sign_in users(:system_admin)
    get clubs_by_region_admin_users_path, params: {region_id: regions(:nbv).id}
    assert_response :success
    data = JSON.parse(response.body)
    assert_kind_of Array, data
    assert(data.all? { |h| h.key?("id") && h.key?("label") })
    assert_includes data.map { |h| h["id"] }, clubs(:bcw).id
  end

  test "locations_by_region: ohne system_admin -> forbidden" do
    sign_in users(:player)
    get locations_by_region_admin_users_path, params: {region_id: regions(:nbv).id}
    assert_response :forbidden
  end

  test "locations_by_region: system_admin bekommt nach Verein gruppierte Spielorte als JSON" do
    clubs(:bcw).update!(region: regions(:nbv))
    sign_in users(:system_admin)
    get locations_by_region_admin_users_path, params: {region_id: regions(:nbv).id}
    assert_response :success
    data = JSON.parse(response.body)
    assert_kind_of Array, data
    assert(data.all? { |g| g.key?("club") && g["locations"].is_a?(Array) })
  end
end
