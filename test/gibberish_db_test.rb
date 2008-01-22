require 'test/unit'
require File.join(File.dirname(__FILE__), '../../../../test/test_helper.rb')
                                            
include Gibberish

class GibberishDbTest < Test::Unit::TestCase
  def test_should_by_default_not_suppress_html_wrapping
    assert !Translation.suppress_html_wrapper?
  end
  
  def test_should_suppress_html_wrapping_within_wrapper_block
    Translation.suppressing_html_wrapping do 
      assert Translation.suppress_html_wrapper?
    end
  end

  def test_should_not_suppress_html_wrapping_after_wrapper_block
    Translation.suppressing_html_wrapping do 
    end
    assert !Translation.suppress_html_wrapper?
  end

  def test_should_not_suppress_html_wrapping_after_wrapper_block_throws_exception
    begin
      Translation.suppressing_html_wrapping do 
        raise "boom!"
      end
    rescue RuntimeError
    end
    assert !Translation.suppress_html_wrapper?
  end
  
  def test_should_handle_nested_suppression_blocks doe
    Translation.suppressing_html_wrapping do 
      Translation.suppressing_html_wrapping do 
        assert Translation.suppress_html_wrapper?
      end                                     
      assert Translation.suppress_html_wrapper?
    end
    assert !Translation.suppress_html_wrapper?
  end
end
