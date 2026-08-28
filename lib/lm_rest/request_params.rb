require 'uri'

module LMRest
  module RequestParams
    def self.parameterize(params_hash)
      return '' if params_hash.nil? || params_hash.empty?

      params = params_hash.each_with_object([]) do |(key, value), pairs|
        next if value.nil?

        values = value.is_a?(Array) ? value : [value]
        values.each { |item| pairs << [key.to_s, item] unless item.nil? }
      end

      return '' if params.empty?

      "?#{URI.encode_www_form(params)}"
    end
  end
end
