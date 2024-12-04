module LMRest
  module RequestParams
    def self.parameterize(params_hash)
      return '' if params_hash.empty?

      params_hash.map.with_index do |(key, value), index|
        prefix = index > 0 ? '&' : '?'
        "#{prefix}#{key}=#{value}"
      end.join
    end
  end
end
