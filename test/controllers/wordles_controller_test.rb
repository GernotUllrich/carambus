require "test_helper"

class WordlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @wordle = wordles(:one)
  end

  test "should get index" do
    get wordles_url
    assert_response :success
  end

  test "should get new" do
    get new_wordle_url
    assert_response :success
  end

  test "should create wordle" do
    assert_difference('Wordle.count') do
      post wordles_url, params: { wordle: { data: @wordle.data, hints: @wordle.hints, seqno: @wordle.seqno, words: @wordle.words } }
    end

    assert_redirected_to wordle_url(Wordle.last)
  end

  test "should show wordle" do
    get wordle_url(@wordle)
    assert_response :success
  end

  test "should get edit" do
    get edit_wordle_url(@wordle)
    assert_response :success
  end

  test "should update wordle" do
    patch wordle_url(@wordle), params: { wordle: { data: @wordle.data, hints: @wordle.hints, seqno: @wordle.seqno, words: @wordle.words } }
    assert_redirected_to wordle_url(@wordle)
  end

  test "should destroy wordle" do
    assert_difference('Wordle.count', -1) do
      delete wordle_url(@wordle)
    end

    assert_redirected_to wordles_url
  end
end
