require "test_helper"

class CurrentHelperTest < ActionView::TestCase
  class LoggedInTest < ActionView::TestCase
    attr_reader :current_user

    setup do
      @current_user = users(:one)
      Current.user = @current_user
    end
  end

  class LoggedOutTest < ActionView::TestCase
    setup do
      Current.reset
    end

    test "current_account should be nil" do
      assert_nil current_account
    end

    test "current_account_user" do
      assert_nil current_account_user
    end

    test "current_user&.admin? returns true for an admin" do
      assert_nil current_account_user
    end

    test "current_user&.admin? returns false for a non admin" do
      assert_not current_user&.admin?
    end

    test "current_roles" do
      assert_empty current_roles
    end
  end
end
