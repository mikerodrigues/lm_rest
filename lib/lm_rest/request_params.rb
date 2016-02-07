class LMRest
  module RequestParams
    def parameterize(params_hash)
      params_hash.keys.each.with_index.reduce('?') do |string, (key, index)|
        index > 0 ? string << '&' : ''
        string << "#{key}=#{hash.fetch(key)}"
      end
    end
  end
end
