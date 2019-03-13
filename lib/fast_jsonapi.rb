# frozen_string_literal: true

module FastJsonapi
  require 'oj'
  require 'fast_jsonapi/object_serializer'
  require 'fast_jsonapi/consts'
  if defined?(::Rails)
    require 'fast_jsonapi/railtie'
  elsif defined?(::ActiveRecord)
    require 'extensions/has_one'
  end
end
