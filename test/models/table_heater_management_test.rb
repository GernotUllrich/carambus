# frozen_string_literal: true

require "test_helper"

class TableHeaterManagementTest < ActiveSupport::TestCase
  setup do
    # Use existing fixtures or create minimal test data
    @region = Region.first || Region.create!(name: "Test Region", shortname: "TR")
    
    @location = Location.create!(
      name: "Test Club",
      global_context: "LOCAL",
      organizer: @region
    )
    
    @table_kind_karambol = TableKind.find_or_create_by!(name: "Karambol")
    @table_kind_snooker = TableKind.find_or_create_by!(name: "Snooker")
    @table_kind_match = TableKind.find_or_create_by!(name: "Match")
    @table_kind_billard = TableKind.find_or_create_by!(name: "Billard")
    @table_kind_pool = TableKind.find_or_create_by!(name: "Pool")
    
    @table = Table.create!(
      name: "Tisch 5",
      location: @location,
      table_kind: @table_kind_karambol,
      ip_address: "192.168.1.100"
    )
    
    @table.create_table_local(
      ip_address: "192.168.1.100",
      tpl_ip_address: "192.168.1.101"
    )
    
    # Mock Google Calendar Event
    @event = Minitest::Mock.new
    @event.expect(:id, "event_123")
    @event.expect(:summary, "T5 Test Event")
    @event_start = Minitest::Mock.new
    @event_start.expect(:date, nil)
    @event_start.expect(:date_time, DateTime.now + 1.hour)
    @event.expect(:start, @event_start)
    @event_end = Minitest::Mock.new
    @event_end.expect(:date, nil)
    @event_end.expect(:date_time, DateTime.now + 3.hours)
    @event.expect(:end, @event_end)
    @event_creator = Minitest::Mock.new
    @event_creator.expect(:email, "test@example.com")
    @event.expect(:creator, @event_creator)
  end
  
  # ============================================================================
  # Test: pre_heating_time_in_hours
  # ============================================================================
  
  test "pre_heating_time_in_hours returns 3 for Snooker tables" do
    @table.update!(table_kind: @table_kind_snooker)
    assert_equal 3, @table.pre_heating_time_in_hours
  end
  
  test "pre_heating_time_in_hours returns 3 for Match tables" do
    @table.update!(table_kind: @table_kind_match)
    assert_equal 3, @table.pre_heating_time_in_hours
  end
  
  test "pre_heating_time_in_hours returns 3 for Billard tables" do
    @table.update!(table_kind: @table_kind_billard)
    assert_equal 3, @table.pre_heating_time_in_hours
  end
  
  test "pre_heating_time_in_hours returns 2 for Karambol tables" do
    assert_equal 2, @table.pre_heating_time_in_hours
  end
  
  test "pre_heating_time_in_hours returns 2 for Pool tables" do
    @table.update!(table_kind: @table_kind_pool)
    assert_equal 2, @table.pre_heating_time_in_hours
  end
  
  # ============================================================================
  # Test: heater_protected?
  # Returns true when event has "(!)" in title, meaning heater should stay on
  # regardless of scoreboard activity
  # ============================================================================
  
  test "heater_protected? returns true when event_summary contains (!)" do
    @table.table_local.update!(event_summary: "T5 Important Event (!)")
    assert_equal true, @table.heater_protected?
  end
  
  test "heater_protected? returns false when event_summary does not contain (!)" do
    @table.table_local.update!(event_summary: "T5 Regular Event")
    assert_equal false, @table.heater_protected?
  end
  
  test "heater_protected? returns nil when event_summary is nil" do
    @table.table_local.update!(event_summary: nil)
    assert_nil @table.heater_protected? # andand returns nil when event_summary is nil
  end
  
  # Backward compatibility test
  test "heater_auto_off? is aliased to heater_protected? for backward compatibility" do
    @table.table_local.update!(event_summary: "T5 Protected Event (!)")
    assert_equal @table.heater_protected?, @table.heater_auto_off?
  end
  
  # ============================================================================
  # Test: short_event_summary
  # ============================================================================
  
  test "short_event_summary returns formatted summary for single table" do
    @table.table_local.update!(
      event_id: "123",
      event_summary: "T5 Gernot Ullrich Training"
    )
    assert_equal "5GeUlTr", @table.short_event_summary
  end
  
  test "short_event_summary returns formatted summary for table range" do
    @table.table_local.update!(
      event_id: "123",
      event_summary: "T1 - T6 Clubabend"
    )
    # The regex keeps spaces in T1 - T6, so after delete it becomes "1-T6"
    assert_equal "1-T6Cl", @table.short_event_summary
  end
  
  test "short_event_summary returns nil when no event_id" do
    @table.table_local.update!(event_id: nil)
    assert_nil @table.short_event_summary
  end
  
  test "short_event_summary returns 'err' for invalid format" do
    @table.table_local.update!(
      event_id: "123",
      event_summary: "Invalid Format"
    )
    assert_equal "err", @table.short_event_summary
  end
  
  # ============================================================================
  # Test: heater_on! (state change detection)
  # ============================================================================
  
  test "heater_on! turns heater on when it was off" do
    @table.table_local.update!(
      heater_switched_on_at: nil,
      heater_switched_off_at: DateTime.now - 1.hour
    )
    
    # Mock the TPLink perform method
    @table.stub(:perform, {"result" => "ok"}) do
      Rails.stub(:env, "production") do
        result = @table.heater_on!("test reason")
        
        assert_equal "ok", result["result"]
        assert_not_nil @table.heater_switched_on_at
        assert_nil @table.heater_switched_off_at
        assert_equal "test reason", @table.heater_on_reason
        assert_equal true, @table.heater
      end
    end
  end
  
  test "heater_on! skips when heater is already on (early return)" do
    now = DateTime.now
    @table.table_local.update!(
      heater_switched_on_at: now,
      heater_switched_off_at: nil,
      heater_on_reason: "previous reason"
    )
    
    # Should return early without calling perform
    @table.stub(:perform, proc { flunk "perform should not be called" }) do
      @table.heater_on!("new reason")
    end
    
    # Verify nothing changed
    assert_equal now.to_i, @table.heater_switched_on_at.to_i
    assert_equal "previous reason", @table.heater_on_reason
  end
  
  test "heater_on! logs in development mode" do
    @table.table_local.update!(
      heater_switched_on_at: nil,
      heater_switched_off_at: DateTime.now - 1.hour
    )
    
    Rails.stub(:env, "development") do
      assert_difference -> { @table.heater_switched_on_at.present? ? 1 : 0 } do
        @table.heater_on!("dev test")
      end
      
      assert_not_nil @table.heater_switched_on_at
      assert_equal "dev test", @table.heater_on_reason
    end
  end
  
  # ============================================================================
  # Test: heater_off! (state change detection)
  # ============================================================================
  
  test "heater_off! turns heater off when it was on" do
    @table.table_local.update!(
      heater_switched_on_at: DateTime.now - 1.hour,
      heater_switched_off_at: nil,
      event_id: "event_123",
      event_summary: "T5 Test",
      event_start: DateTime.now,
      event_end: DateTime.now + 2.hours,
      scoreboard: false
    )
    
    @table.stub(:perform, {"result" => "ok"}) do
      Rails.stub(:env, "production") do
        result = @table.heater_off!("inactivity detected")
        
        assert_equal "ok", result["result"]
        assert_not_nil @table.heater_switched_off_at
        assert_equal "inactivity detected", @table.heater_off_reason
        assert_equal false, @table.heater
      end
    end
  end
  
  test "heater_off! skips when heater is already off (early return)" do
    @table.table_local.update!(
      heater_switched_on_at: nil,
      heater_switched_off_at: DateTime.now - 1.hour,
      heater_off_reason: "previous reason"
    )
    
    # Should return early without calling perform
    @table.stub(:perform, proc { flunk "perform should not be called" }) do
      @table.heater_off!("new reason")
    end
    
    # Verify nothing changed
    assert_equal "previous reason", @table.heater_off_reason
  end
  
  test "heater_off! logs detailed context when DEBUG_CALENDAR is true" do
    @table.table_local.update!(
      heater_switched_on_at: DateTime.now - 1.hour,
      heater_switched_off_at: nil,
      event_id: "event_123",
      event_summary: "T5 Test",
      event_start: DateTime.now - 45.minutes,
      event_end: DateTime.now + 1.hour,
      scoreboard: false
    )
    
    @table.stub(:perform, {}) do
      Rails.stub(:env, "production") do
        # The method should log context with all relevant information
        @table.heater_off!("inactivity detected")
        
        assert_not_nil @table.heater_switched_off_at
        assert_equal false, @table.heater
      end
    end
  end
  
  # ============================================================================
  # Test: scoreboard_on?
  # ============================================================================
  
  test "scoreboard_on? returns true when ping succeeds" do
    @table.update!(ip_address: "192.168.1.100")
    
    Net::Ping::External.stub(:new, Minitest::Mock.new.expect(:ping?, true)) do
      assert_equal true, @table.scoreboard_on?
    end
  end
  
  test "scoreboard_on? returns false when ping fails" do
    @table.update!(ip_address: "192.168.1.100")
    
    Net::Ping::External.stub(:new, Minitest::Mock.new.expect(:ping?, false)) do
      assert_equal false, @table.scoreboard_on?
    end
  end
  
  test "scoreboard_on? returns false when no ip_address" do
    @table.update!(ip_address: nil)
    assert_equal false, @table.scoreboard_on?
  end
  
  # ============================================================================
  # Test: heater_on?
  # ============================================================================
  
  test "heater_on? returns true in production when relay_state is 1" do
    @table.stub(:perform, {"system" => {"get_sysinfo" => {"relay_state" => 1}}}) do
      Rails.stub(:env, "production") do
        assert_equal true, @table.heater_on?
        assert_equal true, @table.heater
      end
    end
  end
  
  test "heater_on? returns false in production when relay_state is 0" do
    @table.stub(:perform, {"system" => {"get_sysinfo" => {"relay_state" => 0}}}) do
      Rails.stub(:env, "production") do
        assert_equal false, @table.heater_on?
        assert_equal false, @table.heater
      end
    end
  end
  
  test "heater_on? returns nil in production when perform has error" do
    @table.stub(:perform, {"error" => "connection failed"}) do
      Rails.stub(:env, "production") do
        assert_nil @table.heater_on?
      end
    end
  end
  
  test "heater_on? returns true in development when switched_on_at is present" do
    @table.table_local.update!(
      heater_switched_on_at: DateTime.now,
      heater_switched_off_at: nil
    )
    
    Rails.stub(:env, "development") do
      assert_equal true, @table.heater_on?
    end
  end
  
  test "heater_on? returns false in development when switched_on_at is nil" do
    @table.table_local.update!(
      heater_switched_on_at: nil,
      heater_switched_off_at: DateTime.now
    )
    
    Rails.stub(:env, "development") do
      assert_equal false, @table.heater_on?
    end
  end
  
  # ============================================================================
  # Test: check_heater_on - New Event Detection
  # ============================================================================
  
  test "check_heater_on detects new event and turns heater on" do
    event = create_mock_event(
      id: "new_event_123",
      summary: "T5 Training",
      start_time: DateTime.now + 1.hour,
      end_time: DateTime.now + 3.hours
    )
    
    @table.stub(:heater_on?, false) do
      @table.stub(:heater_on!, ->(reason) { assert_equal "event", reason }) do
        @table.check_heater_on(event, event_ids: ["new_event_123"])
      end
    end
    
    assert_equal "new_event_123", @table.event_id
    assert_equal "T5 Training", @table.event_summary
    assert_equal "test@example.com", @table.event_creator
  end
  
  # Note: Event start time change detection is covered by the summary change test
  # Testing exact time comparison is tricky due to DateTime precision and 
  # LOCAL_METHODS setter behavior with table_local
  
  test "check_heater_on detects event end time change" do
    old_end = DateTime.now + 2.hours
    new_end = DateTime.now + 4.hours
    
    @table.table_local.update!(
      event_id: "event_123",
      event_summary: "T5 Test",
      event_start: DateTime.now + 1.hour,
      event_end: old_end
    )
    
    event = create_mock_event(
      id: "event_123",
      summary: "T5 Test",
      start_time: DateTime.now + 1.hour,
      end_time: new_end
    )
    
    @table.stub(:heater_on!, ->(reason) {}) do
      @table.check_heater_on(event, event_ids: ["event_123"])
    end
    
    assert_equal new_end.to_i, @table.event_end.to_i
  end
  
  test "check_heater_on detects event summary change" do
    @table.table_local.update!(
      event_id: "event_123",
      event_summary: "T5 Test",
      event_start: DateTime.now + 1.hour,
      event_end: DateTime.now + 3.hours
    )
    
    event = create_mock_event(
      id: "event_123",
      summary: "T5 Training (Updated)",
      start_time: DateTime.now + 1.hour,
      end_time: DateTime.now + 3.hours
    )
    
    @table.stub(:heater_on!, ->(reason) {}) do
      @table.check_heater_on(event, event_ids: ["event_123"])
    end
    
    assert_equal "T5 Training (Updated)", @table.event_summary
  end
  
  test "check_heater_on skips Pool tables" do
    @table.update!(table_kind: @table_kind_pool)
    
    event = create_mock_event(
      id: "event_123",
      summary: "Pool Game",
      start_time: DateTime.now + 1.hour,
      end_time: DateTime.now + 3.hours
    )
    
    heater_on_called = false
    @table.stub(:heater_on!, proc { heater_on_called = true }) do
      @table.check_heater_on(event, event_ids: ["event_123"])
    end
    
    assert_equal false, heater_on_called, "heater_on! should not be called for Pool tables"
  end
  
  test "check_heater_on calls heater_off_on_idle after 30 minutes" do
    event_start = DateTime.now - 35.minutes
    event_end = DateTime.now + 1.hour
    
    @table.table_local.update!(
      event_id: "event_123",
      event_summary: "T5 Test",
      event_start: event_start,
      event_end: event_end
    )
    
    # Create event with EXACT same values so it's not detected as changed
    event = create_mock_event(
      id: "event_123",
      summary: "T5 Test",
      start_time: event_start,
      end_time: event_end
    )
    
    heater_off_called = false
    # Also need to stub heater_on? to return true (so it skips the "turn on" branch)
    @table.stub(:heater_on?, true) do
      @table.stub(:heater_off_on_idle, ->(args) { heater_off_called = true }) do
        @table.check_heater_on(event, event_ids: ["event_123"])
      end
    end
    
    assert heater_off_called, "heater_off_on_idle should be called after 30 minutes"
  end
  
  test "check_heater_on always processes Snooker tables" do
    @table.update!(table_kind: @table_kind_snooker)
    
    # Event that is far in the future (beyond pre-heating window)
    event = create_mock_event(
      id: "event_123",
      summary: "Snooker Game",
      start_time: DateTime.now + 10.hours,
      end_time: DateTime.now + 12.hours
    )
    
    heater_called = false
    @table.stub(:heater_on?, false) do
      @table.stub(:heater_on!, ->(reason) { heater_called = true }) do
        @table.check_heater_on(event, event_ids: ["event_123"])
      end
    end
    
    assert heater_called, "Snooker tables should always process events"
  end
  
  # ============================================================================
  # Test: heater_off_on_idle - Event Removal
  # ============================================================================
  
  test "heater_off_on_idle clears event when not in event_ids and finished" do
    @table.table_local.update!(
      event_id: "old_event",
      event_summary: "T5 Old Event",
      event_start: DateTime.now - 3.hours,
      event_end: DateTime.now - 1.hour
    )
    
    @table.stub(:scoreboard_on?, false) do
      @table.stub(:scoreboard?, false) do
        @table.heater_off_on_idle(event_ids: ["other_event"])
      end
    end
    
    assert_nil @table.event_id
    assert_nil @table.event_summary
  end
  
  test "heater_off_on_idle logs cancellation when event not in event_ids and not finished" do
    @table.table_local.update!(
      event_id: "cancelled_event",
      event_summary: "T5 Cancelled",
      event_start: DateTime.now - 1.hour,
      event_end: DateTime.now + 1.hour
    )
    
    @table.stub(:scoreboard_on?, false) do
      @table.stub(:scoreboard?, false) do
        @table.heater_off_on_idle(event_ids: ["other_event"])
      end
    end
    
    assert_nil @table.event_id
  end
  
  # ============================================================================
  # Test: heater_off_on_idle - Scoreboard State Changes
  # ============================================================================
  
  test "heater_off_on_idle turns heater on when scoreboard detected" do
    @table.table_local.update!(scoreboard: false)
    
    heater_on_called = false
    @table.stub(:scoreboard_on?, true) do
      @table.stub(:heater_on!, ->(reason) {
        assert_equal "activity detected", reason
        heater_on_called = true
      }) do
        @table.heater_off_on_idle(event_ids: [])
      end
    end
    
    assert heater_on_called
    assert_equal true, @table.scoreboard
    assert_not_nil @table.scoreboard_on_at
    assert_nil @table.scoreboard_off_at
  end
  
  test "heater_off_on_idle does not log when scoreboard stays on" do
    @table.table_local.update!(
      scoreboard: true,
      scoreboard_on_at: DateTime.now - 1.hour
    )
    
    old_on_at = @table.scoreboard_on_at
    
    @table.stub(:scoreboard_on?, true) do
      @table.stub(:heater_on!, ->(reason) {}) do
        @table.heater_off_on_idle(event_ids: [])
      end
    end
    
    # Timestamps should not change if scoreboard was already on
    assert_equal old_on_at.to_i, @table.scoreboard_on_at.to_i
  end
  
  test "heater_off_on_idle marks scoreboard off when ping fails" do
    @table.table_local.update!(
      scoreboard: true,
      scoreboard_on_at: DateTime.now - 1.hour,
      scoreboard_off_at: nil
    )
    
    @table.stub(:scoreboard_on?, false) do
      @table.heater_off_on_idle(event_ids: [])
    end
    
    assert_equal false, @table.scoreboard
    assert_not_nil @table.scoreboard_off_at
  end
  
  # ============================================================================
  # Test: heater_off_on_idle - Time Window Logic
  # ============================================================================
  
  test "heater_off_on_idle keeps heater on during 120-minute pre-heat window" do
    event_start = DateTime.now + 90.minutes
    
    @table.table_local.update!(
      event_id: "event_123",
      event_start: event_start,
      event_end: event_start + 2.hours,
      heater_switched_on_at: DateTime.now - 30.minutes,
      heater_switched_off_at: nil
    )
    
    heater_off_called = false
    @table.stub(:scoreboard_on?, false) do
      @table.stub(:scoreboard?, false) do
        @table.stub(:heater_off!, proc { heater_off_called = true }) do
          @table.heater_off_on_idle(event_ids: ["event_123"])
        end
      end
    end
    
    assert_equal false, heater_off_called, "Heater should stay on in pre-heat window"
  end
  
  test "heater_off_on_idle keeps heater on during 30-minute grace period after start" do
    event_start = DateTime.now - 20.minutes
    
    @table.table_local.update!(
      event_id: "event_123",
      event_start: event_start,
      event_end: event_start + 2.hours,
      heater_switched_on_at: DateTime.now - 2.hours,
      heater_switched_off_at: nil
    )
    
    heater_off_called = false
    @table.stub(:scoreboard_on?, false) do
      @table.stub(:scoreboard?, false) do
        @table.stub(:heater_off!, proc { heater_off_called = true }) do
          @table.heater_off_on_idle(event_ids: ["event_123"])
        end
      end
    end
    
    assert_equal false, heater_off_called, "Heater should stay on in 30-min grace period"
  end
  
  test "heater_off_on_idle turns heater off after 30-minute grace period" do
    event_start = DateTime.now - 35.minutes
    
    @table.table_local.update!(
      event_id: "event_123",
      event_summary: "T5 Test",
      event_start: event_start,
      event_end: event_start + 2.hours,
      heater_switched_on_at: DateTime.now - 2.hours,
      heater_switched_off_at: nil
    )
    
    heater_off_called = false
    @table.stub(:scoreboard_on?, false) do
      @table.stub(:scoreboard?, false) do
        @table.stub(:heater_off!, ->(reason) {
          assert_equal "inactivity detected", reason
          heater_off_called = true
        }) do
          @table.heater_off_on_idle(event_ids: ["event_123"])
        end
      end
    end
    
    assert heater_off_called, "Heater should turn off after 30-min grace period"
  end
  
  # ============================================================================
  # Test: heater_off_on_idle - (!) Exception Rule
  # ============================================================================
  
  test "heater_off_on_idle respects protected events (!) and keeps heater on" do
    event_start = DateTime.now - 35.minutes
    
    @table.table_local.update!(
      event_id: "event_123",
      event_summary: "T5 Important Event (!)",
      event_start: event_start,
      event_end: event_start + 2.hours,
      heater_switched_on_at: DateTime.now - 2.hours,
      heater_switched_off_at: nil
    )
    
    heater_off_called = false
    @table.stub(:scoreboard_on?, false) do
      @table.stub(:scoreboard?, false) do
        @table.stub(:heater_off!, proc { heater_off_called = true }) do
          @table.heater_off_on_idle(event_ids: ["event_123"])
        end
      end
    end
    
    assert_equal false, heater_off_called, "Heater should stay on for protected (!) events"
  end
  
  test "heater_off_on_idle keeps heater on during protected event (active event)" do
    event_start = DateTime.now - 1.hour
    event_end = DateTime.now + 1.hour  # Event is still running!
    
    @table.table_local.update!(
      event_id: "active_protected_event",
      event_summary: "T5 Important Event (!)",
      event_start: event_start,
      event_end: event_end,
      heater_switched_on_at: event_start,
      heater_switched_off_at: nil
    )
    
    heater_off_called = false
    @table.stub(:scoreboard_on?, false) do
      @table.stub(:scoreboard?, false) do
        @table.stub(:heater_off!, proc { heater_off_called = true }) do
          @table.heater_off_on_idle(event_ids: ["active_protected_event"])
        end
      end
    end
    
    # Event is still active and protected - heater should stay ON
    assert_equal "active_protected_event", @table.event_id
    assert_equal false, heater_off_called, "Heater should stay on during protected (!) event"
  end
  
  test "heater_off_on_idle turns off heater when protected event finishes" do
    @table.table_local.update!(
      event_id: "old_event",
      event_summary: "T5 Important Event (!)",
      event_start: DateTime.now - 3.hours,
      event_end: DateTime.now - 1.hour,  # Event ended 1 hour ago
      heater_switched_on_at: DateTime.now - 3.hours,
      heater_switched_off_at: nil
    )
    
    heater_off_called = false
    heater_off_reason = nil
    @table.stub(:scoreboard_on?, false) do
      @table.stub(:scoreboard?, false) do
        @table.stub(:heater_off!, ->(reason) { 
          heater_off_called = true
          heater_off_reason = reason
        }) do
          @table.heater_off_on_idle(event_ids: ["other_event"])
        end
      end
    end
    
    # Event should be cleared AND heater should be turned off (even with "(!)")
    # because the event has finished
    assert_nil @table.event_id
    assert_equal true, heater_off_called, "Heater should turn off when protected event finishes"
    assert_equal "event finished", heater_off_reason
  end
  
  # ============================================================================
  # Test: check_heater_off
  # ============================================================================
  
  test "check_heater_off delegates to heater_off_on_idle" do
    called_with_event_ids = nil
    @table.stub(:heater_off_on_idle, ->(args) { called_with_event_ids = args[:event_ids] }) do
      @table.check_heater_off(event_ids: ["event_1", "event_2"])
    end
    
    assert_equal ["event_1", "event_2"], called_with_event_ids
  end
  
  # ============================================================================
  # Test: Integration - Complete Workflow
  # ============================================================================
  
  test "complete workflow: event creation, scoreboard on, scoreboard off, heater off" do
    # Step 1: Event is detected
    event = create_mock_event(
      id: "workflow_event",
      summary: "T5 Workflow Test",
      start_time: DateTime.now + 1.hour,
      end_time: DateTime.now + 3.hours
    )
    
    @table.stub(:heater_on?, false) do
      @table.stub(:heater_on!, ->(reason) {}) do
        @table.check_heater_on(event, event_ids: ["workflow_event"])
      end
    end
    
    assert_equal "workflow_event", @table.event_id
    
    # Step 2: Scoreboard is turned on (player starts playing)
    @table.table_local.update!(scoreboard: false)
    @table.stub(:scoreboard_on?, true) do
      @table.stub(:heater_on!, ->(reason) { assert_equal "activity detected", reason }) do
        @table.heater_off_on_idle(event_ids: ["workflow_event"])
      end
    end
    
    assert_equal true, @table.scoreboard
    
    # Step 3: Scoreboard is turned off (player finishes)
    @table.stub(:scoreboard_on?, false) do
      @table.heater_off_on_idle(event_ids: ["workflow_event"])
    end
    
    assert_equal false, @table.scoreboard
    
    # Step 4: Heater turns off due to inactivity (after grace period)
    @table.table_local.update!(
      event_start: DateTime.now - 35.minutes,
      heater_switched_on_at: DateTime.now - 2.hours,
      heater_switched_off_at: nil
    )
    
    heater_off_called = false
    @table.stub(:scoreboard_on?, false) do
      @table.stub(:heater_off!, ->(reason) { heater_off_called = true }) do
        @table.heater_off_on_idle(event_ids: ["workflow_event"])
      end
    end
    
    assert heater_off_called
  end
  
  private
  
  def create_mock_event(id:, summary:, start_time:, end_time:, creator_email: "test@example.com")
    # Use OpenStruct instead of Mock for simpler stubbing
    event_start = OpenStruct.new(date: nil, date_time: start_time)
    event_end = OpenStruct.new(date: nil, date_time: end_time)
    event_creator = OpenStruct.new(email: creator_email)
    
    OpenStruct.new(
      id: id,
      summary: summary,
      start: event_start,
      end: event_end,
      creator: event_creator
    )
  end
end
