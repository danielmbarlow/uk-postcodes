require 'test_helper'

class PostcodeTest < ActiveSupport::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    # Do nothing
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  def test_nearest

    #Position in Buckingham included in the test data from the test fixtures
    distance = 1 * 1609.344
    nearest = Postcode.nearest('51.999626', '-0.986037', distance)

    #Postcode should be a full postcode
    assert_not_nil(nearest)
    assert(nearest.count > 0)
    assert(nearest.first.postcode == 'MK18 1GD')
  end
end