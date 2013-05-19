require 'test_helper'

class PaymentsControllerTest < ActionController::TestCase
  test "should get start" do
    get :start
    assert_response :success
  end

  test "should get finish" do
    get :finish
    assert_response :success
  end

end
