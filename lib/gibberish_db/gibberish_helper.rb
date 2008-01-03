module ERB::Util
  #output the gibberish translation with enough information to make it inline editable
  #with some fancy javascript
  def h_with_gibberish_support(s)
    if s.is_a?(Gibberish::Translation)
      %Q{<span class="translated key_#{s.key}" lang="#{s.language.name}">#{s}</span>}
    else
      h_without_gibberish_support(s)
    end
  end
  
  alias_method_chain :h, :gibberish_support
end