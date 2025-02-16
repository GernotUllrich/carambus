test "should protect imported records" do
  imported = tournaments(:imported)
  assert imported.readonly?
  assert_raises(ActiveRecord::ReadOnlyRecord) { imported.update!(title: "New Title") }
end

test "allows local modifications to data field" do
  local = tournaments(:local)
  assert_nothing_raised do
    local.update!(data: { new_setting: true })
  end
end 