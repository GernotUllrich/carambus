# frozen_string_literal: true

require "test_helper"

# Charakterisierungs-Test fuer die Instanz-Rollen-Ableitung (Plan 32-02).
# instance_role liest Carambus.config ueber local_server? + location_id_config; wir stubben beide
# (minitest/mock Object#stub), damit der Test deterministisch ist und nicht von der lokalen dev-Config
# abhaengt. Verhaltenserhalt: byte-gleiche Ableitung zur frueheren Diagnostics::ChainCheck#role-Logik.
class ApplicationRecordRoleTest < ActiveSupport::TestCase
  test "authority when not a local server" do
    ApplicationRecord.stub(:local_server?, false) do
      assert_equal :authority, ApplicationRecord.instance_role
      assert ApplicationRecord.authority?
      assert_not ApplicationRecord.region_server?
      assert_not ApplicationRecord.location_server?
    end
  end

  test "region_server when local server without location_id" do
    ApplicationRecord.stub(:local_server?, true) do
      ApplicationRecord.stub(:location_id_config, nil) do
        assert_equal :region_server, ApplicationRecord.instance_role
        assert ApplicationRecord.region_server?
        assert_not ApplicationRecord.authority?
        assert_not ApplicationRecord.location_server?
      end

      # location_id == 0 ist ebenfalls Region Server (nur > 0 ist Location Server)
      ApplicationRecord.stub(:location_id_config, 0) do
        assert_equal :region_server, ApplicationRecord.instance_role
      end
    end
  end

  test "location_server when local server with positive location_id" do
    ApplicationRecord.stub(:local_server?, true) do
      ApplicationRecord.stub(:location_id_config, 2426) do
        assert_equal :location_server, ApplicationRecord.instance_role
        assert ApplicationRecord.location_server?
        assert_not ApplicationRecord.authority?
        assert_not ApplicationRecord.region_server?
      end
    end
  end

  test "exactly one role predicate is true in every configuration" do
    [[false, nil], [true, nil], [true, 0], [true, 2426]].each do |local, loc|
      ApplicationRecord.stub(:local_server?, local) do
        ApplicationRecord.stub(:location_id_config, loc) do
          trues = [
            ApplicationRecord.authority?,
            ApplicationRecord.region_server?,
            ApplicationRecord.location_server?
          ].count(true)
          assert_equal 1, trues, "expected exactly one true role for local=#{local} loc=#{loc.inspect}"
        end
      end
    end
  end
end
