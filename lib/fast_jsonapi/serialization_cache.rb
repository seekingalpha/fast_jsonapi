# frozen_string_literal: true

module FastJsonapi
  module Cache
    class SerializationCacheBase
      extend ::Forwardable

      CACHE_SIZE = (::ENV['FAST_JSONAPI::CACHE_SIZE'].presence || 256).to_i
      CACHE_TTL = (::ENV['FAST_JSONAPI::CACHE_TTL'].presence || 1.minutes).to_i
      attr_accessor :__cache

      def initialize
        @__cache = ::LruRedux::TTL::Cache.new(CACHE_SIZE, CACHE_TTL)
      end

      def_delegators :@__cache, :getset
      def_delegators :@__cache, :clear
    end

    class SerializationCache < SerializationCacheBase
      include ::Singleton
    end
  end
end
