# frozen_string_literal: true

module FastJsonapi
  require 'forwardable'
  require 'singleton'
  require 'zlib'
  require 'logger'

  require 'active_support/time'
  require 'active_support/json'
  require 'active_support/concern'
  require 'active_support/inflector'
  require 'active_support/core_ext/numeric/time'
  require 'active_support/notifications'

  require 'lru_redux'
  require 'oj'
  require 'lru_redux'

  require 'fast_jsonapi/serialization_cache'
  require 'fast_jsonapi/consts'
  require 'fast_jsonapi/base_field'
  require 'fast_jsonapi/attribute'
  require 'fast_jsonapi/link'
  require 'fast_jsonapi/relationship'
  require 'fast_jsonapi/object_serializer'

  if defined?(::Rails)
    require 'fast_jsonapi/railtie'
  elsif defined?(::ActiveRecord)
    require 'extensions/has_one'
  end
end
