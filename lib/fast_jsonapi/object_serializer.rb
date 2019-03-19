# frozen_string_literal: true

module FastJsonapi
  MandatoryField = Class.new(StandardError)
  CACHE          = Cache::SerializationCache.instance

  module ObjectSerializer
    extend ::ActiveSupport::Concern

    SERIALIZABLE_HASH_NOTIFICATION = 'render.fast_jsonapi.serializable_hash'
    SERIALIZED_JSON_NOTIFICATION = 'render.fast_jsonapi.serialized_json'
    DEFAULT_CACHE_PREFIX_KEY = ''
    COMPUTE_SERIALIZER_NAME_RX = /()?\w+Serializer$/

    included do
      class << self
        attr_accessor :attributes_to_serialize,
                      :relationships_to_serialize,
                      :cachable_relationships_to_serialize,
                      :uncachable_relationships_to_serialize,
                      :transform_method,
                      :record_type,
                      :record_id,
                      :prefix_key,
                      :vary_cache_params,
                      :vary_cache_attributes,
                      :cached,
                      :data_links,
                      :meta_to_serialize
      end
      # Set record_type based on the name of the serializer class
      set_type(reflected_record_type) if reflected_record_type
    end

    def initialize(resource, options = ::FastJsonapi::Consts::EMPTY_HASH)
      process_options(options)

      @resource = resource
    end

    def serializable_hash
      return hash_for_collection if is_collection?(@resource, @is_collection)

      hash_for_one_record
    end
    alias_method :to_hash, :serializable_hash

    def hash_for_one_record
      serializable_hash = { data: nil }
      serializable_hash[:included] = @included if @includes && !@includes.empty?
      if @meta && !@meta.empty?
        serializable_hash[:meta] = @meta.transform_keys { |k| self.class.run_key_transform(k) }
      end

      if @links && !@links.empty?
        serializable_hash[:links] = @links.transform_keys { |k| self.class.run_key_transform(k) }
      end

      return serializable_hash unless @resource

      record_type = self.class.record_type || @resource.class.name.demodulize.underscore
      @known_included_objects["#{record_type}_#{self.class.id_from_record(@resource)}"] = @resource

      serializable_hash[:data] = self.class.record_hash(@resource, @fieldsets[self.class.record_type.to_sym], @params)
      serializable_hash[:included] = self.class.get_included_records(@resource, @includes, @known_included_objects, @fieldsets, @params) if @includes.present?
      serializable_hash
    end

    def hash_for_collection
      serializable_hash = {}

      data = []
      included = []
      fieldset = @fieldsets[self.class.record_type.to_sym]
      @resource.each do |record|
        record_type = self.class.record_type || record.class.name.demodulize.underscore
        @known_included_objects["#{record_type}_#{self.class.id_from_record(record)}"] = record

        data << self.class.record_hash(record, fieldset, @params)
        included.concat self.class.get_included_records(record, @includes, @known_included_objects, @fieldsets, @params) if @includes.present?
      end

      serializable_hash[:data] = data
      serializable_hash[:included] = included if @includes && !@includes.empty?
      if @meta && !@meta.empty?
        serializable_hash[:meta] = @meta.transform_keys { |k| self.class.run_key_transform(k) }
      end

      if @links && !@links.empty?
        serializable_hash[:links] = @links.transform_keys { |k| self.class.run_key_transform(k) }
      end

      serializable_hash
    end

    def serialized_json
      self.class.to_json(serializable_hash)
    end

    private

    def process_options(options)
      @fieldsets = options[:fields] || ::FastJsonapi::Consts::EMPTY_HASH
      @params    = {}
      @known_included_objects = {}

      return if !options || options.empty?

      @meta                   = options[:meta]
      @links                  = options[:links]
      @is_collection          = options[:is_collection]
      @params                 = options[:params] || {}
      raise ::ArgumentError.new("`params` option passed to serializer must be a hash") unless @params.is_a?(::Hash)

      @includes = options[:include].deep_dup if options[:include]

      if @includes && options[:include_validation]
        @includes.reject!(&:blank?)
        @includes.map!(&:to_sym)
        self.class.validate_includes!(@includes)
      end
    end

    def deep_symbolize(collection)
      if collection.is_a? ::Hash
        ::Hash[collection.map do |k, v|
          [k.to_sym, deep_symbolize(v)]
        end]
      elsif collection.is_a? ::Array
        collection.map { |i| deep_symbolize(i) }
      else
        collection.to_sym
      end
    end

    def is_collection?(resource, force_is_collection = nil)
      return force_is_collection unless force_is_collection.nil?

      resource.respond_to?(:size) && !resource.respond_to?(:each_pair)
    end

    class_methods do

      def inherited(subclass)
        super(subclass)
        subclass.attributes_to_serialize = attributes_to_serialize.dup if attributes_to_serialize.present?
        subclass.relationships_to_serialize = relationships_to_serialize.dup if relationships_to_serialize.present?
        subclass.cachable_relationships_to_serialize = cachable_relationships_to_serialize.dup if cachable_relationships_to_serialize.present?
        subclass.uncachable_relationships_to_serialize = uncachable_relationships_to_serialize.dup if uncachable_relationships_to_serialize.present?
        subclass.transform_method = transform_method
        subclass.prefix_key = prefix_key
        subclass.vary_cache_params = vary_cache_params
        subclass.vary_cache_attributes = vary_cache_attributes
        subclass.data_links = data_links.dup if data_links.present?
        subclass.cached = cached
        subclass.set_type(subclass.reflected_record_type) if subclass.reflected_record_type
        subclass.meta_to_serialize = meta_to_serialize
      end

      def reflected_record_type
        @reflected_record_type ||= begin
          if self&.name&.end_with?('Serializer')
            self.name.split('::').last.chomp('Serializer').underscore.to_sym
          end
        end
      end

      def set_key_transform(transform_name)
        mapping = {
            camel: :camelize,
            camel_lower: [:camelize, :lower],
            dash: :dasherize,
            underscore: :underscore
        }
        self.transform_method = mapping[transform_name.to_sym]

        # ensure that the record type is correctly transformed
        if record_type
          set_type(record_type)
        elsif reflected_record_type
          set_type(reflected_record_type)
        end
      end

      def run_key_transform(input)
        if self.transform_method.present?
          input.to_s.send(*@transform_method).to_sym
        else
          input.to_sym
        end
      end

      def use_hyphen
        warn('DEPRECATION WARNING: use_hyphen is deprecated and will be removed from fast_jsonapi 2.0 use (set_key_transform :dash) instead')
        set_key_transform :dash
      end

      def set_type(type_name)
        self.record_type = run_key_transform(type_name)
      end

      def set_id(id_name = nil, &block)
        self.record_id = block || id_name
      end

      def cache_options(cache_options)
        self.prefix_key = cache_options[:prefix_key] || DEFAULT_CACHE_PREFIX_KEY
        self.cached = cache_options[:enabled] || false
      end

      def vary_attributes(*attributes_list)
        attributes_list = attributes_list.first if attributes_list.first.class.is_a?(::Array)

        self.vary_cache_attributes = [] if self.vary_cache_attributes.blank?
        self.vary_cache_attributes += attributes_list
      end
      alias_method :vary_attribute, :vary_attributes

      def vary_params(*attributes_list)
        attributes_list = attributes_list.first if attributes_list.first.class.is_a?(::Array)
        self.vary_cache_params = [] if self.vary_cache_params.blank?
        self.vary_cache_params += attributes_list
      end
      alias_method :vary_param, :vary_params

      def attributes(*attributes_list, &block)
        attributes_list = attributes_list.first if attributes_list.first.class.is_a?(::Array)
        options = attributes_list.last.is_a?(::Hash) ? attributes_list.pop : ::FastJsonapi::Consts::EMPTY_HASH
        self.attributes_to_serialize = {} if self.attributes_to_serialize.nil?

        attributes_list.each do |attr_name|
          method_name = attr_name
          key = run_key_transform(method_name)
          attributes_to_serialize[key] = Attribute.new(
              key: key,
              method: block || method_name,
              options: options
          )
        end
      end

      alias_method :attribute, :attributes

      def add_relationship(relationship)
        self.relationships_to_serialize = {} if relationships_to_serialize.nil?
        self.cachable_relationships_to_serialize = {} if cachable_relationships_to_serialize.nil?
        self.uncachable_relationships_to_serialize = {} if uncachable_relationships_to_serialize.nil?

        if !relationship.cached
          self.uncachable_relationships_to_serialize[relationship.name] = relationship
        else
          self.cachable_relationships_to_serialize[relationship.name] = relationship
        end
        self.relationships_to_serialize[relationship.name] = relationship
      end

      def has_many(relationship_name, options = ::FastJsonapi::Consts::EMPTY_HASH, &block)
        relationship = create_relationship(relationship_name, :has_many, options, block)
        add_relationship(relationship)
      end

      def has_one(relationship_name, options = ::FastJsonapi::Consts::EMPTY_HASH, &block)
        relationship = create_relationship(relationship_name, :has_one, options, block)
        add_relationship(relationship)
      end

      def belongs_to(relationship_name, options = ::FastJsonapi::Consts::EMPTY_HASH, &block)
        relationship = create_relationship(relationship_name, :belongs_to, options, block)
        add_relationship(relationship)
      end

      def meta(&block)
        self.meta_to_serialize = block
      end

      def create_relationship(base_key, relationship_type, options, block)
        name = base_key.to_sym
        if relationship_type == :has_many
          base_serialization_key = base_key.to_s.singularize
          base_key_sym = base_serialization_key.to_sym
          id_postfix = '_ids'
        else
          base_serialization_key = base_key
          base_key_sym = name
          id_postfix = '_id'
        end
        Relationship.new(
            key: options[:key] || run_key_transform(base_key),
            name: name,
            id_method_name: compute_id_method_name(
                options[:id_method_name],
                "#{base_serialization_key}#{id_postfix}".to_sym,
                block
            ),
            record_type: options[:record_type] || run_key_transform(base_key_sym),
            object_method_name: options[:object_method_name] || name,
            object_block: block,
            serializer: compute_serializer_name(options[:serializer] || base_key_sym),
            relationship_type: relationship_type,
            cached: options[:cached],
            polymorphic: fetch_polymorphic_option(options),
            conditional_proc: options[:if],
            transform_method: @transform_method,
            links: options[:links],
            lazy_load_data: options[:lazy_load_data]
        )
      end

      def compute_id_method_name(custom_id_method_name, id_method_name_from_relationship, block)
        if block.present?
          custom_id_method_name || :id
        else
          custom_id_method_name || id_method_name_from_relationship
        end
      end

      def compute_serializer_name(serializer_key)
        return serializer_key unless serializer_key.respond_to?(:id2name)

        namespace = self.name.gsub(COMPUTE_SERIALIZER_NAME_RX, '')
        serializer_name = serializer_key.to_s.classify + 'Serializer'

        (namespace + serializer_name).to_sym
      end

      def fetch_polymorphic_option(options)
        option = options[:polymorphic]
        return false unless option.present?
        return option if option.respond_to?(:keys)
        ::FastJsonapi::Consts::EMPTY_HASH
      end

      def link(link_name, link_method_name = nil, &block)
        self.data_links = {} if self.data_links.nil?
        link_method_name = link_name if link_method_name.nil?
        key = run_key_transform(link_name)

        self.data_links[key] = Link.new(
            key: key,
            method: block || link_method_name
        )
      end

      def validate_includes!(includes)
        return if includes.blank?

        includes.detect do |include_item|
          klass = self
          parse_include_item(include_item).each do |parsed_include|
            relationships_to_serialize = klass.relationships_to_serialize || ::FastJsonapi::Consts::EMPTY_HASH
            relationship_to_include = relationships_to_serialize[parsed_include]
            raise ::ArgumentError, "#{parsed_include} is not specified as a relationship on #{klass.name}" unless relationship_to_include
            klass = relationship_to_include.serializer.to_s.constantize unless relationship_to_include.polymorphic.is_a?(::Hash)
          end
        end
      end

      def record_hash_cache_key(fieldset, record, params)
        cache_hash = {
            fieldset:    fieldset,
            prefix_key:  self.prefix_key,
            name:        self.name,
            record_type: self.record_type,
            cache_key:   record.cache_key
        }

        vary_cache_params&.each_with_object(cache_hash) do |it, collector|
          collector["vary_param_#{it}".to_sym] = params[it]
        end

        vary_cache_attributes&.each_with_object(cache_hash) do |it, collector|
          collector["vary_attribute_#{it}".to_sym] = record.public_send(it)
        end

        hash_json = Oj.dump(cache_hash, mode: :compat)
        Zlib.crc32(hash_json)
      end

      def id_hash(id, record_type, default_return = false)
        if id.present?
          { id: id.to_s, type: record_type }
        else
          default_return ? { id: nil, type: record_type } : nil
        end
      end

      def links_hash(record, params = {})
        data_links.each_with_object({}) do |(_k, link), hash|
          link.serialize(record, params, hash)
        end
      end

      def attributes_hash(record, fieldset = nil, params = {})
        attributes = attributes_to_serialize
        attributes = attributes.slice(*fieldset) if fieldset.present?
        attributes.each_with_object({}) do |(_k, attribute), hash|
          attribute.serialize(record, params, hash)
        end
      end

      def relationships_hash(record, relationships = nil, fieldset = nil, params = {})
        relationships = relationships_to_serialize if relationships.nil?
        relationships = relationships.slice(*fieldset) if fieldset.present?

        relationships.each_with_object({}) do |(_k, relationship), hash|
          relationship.serialize(record, params, hash)
        end
      end

      def meta_hash(record, params = {})
        meta_to_serialize.call(record, params)
      end

      def record_hash(record, fieldset, params = {})
        if cached
          cache_key = record_hash_cache_key(fieldset, record, params)

          record_hash                 = CACHE.getset(cache_key) do
            temp_hash                 = id_hash(id_from_record(record), record_type, true)
            temp_hash[:attributes]    = attributes_hash(record, fieldset, params) if attributes_to_serialize.present?
            temp_hash[:relationships] = {}
            temp_hash[:relationships] = relationships_hash(record, cachable_relationships_to_serialize, fieldset, params) if cachable_relationships_to_serialize.present?
            temp_hash[:links]         = links_hash(record, params) if data_links.present?
            temp_hash
          end
          record_hash[:relationships] = record_hash[:relationships].merge(relationships_hash(record, uncachable_relationships_to_serialize, fieldset, params)) if uncachable_relationships_to_serialize.present?
          record_hash[:meta]          = meta_hash(record, params) if meta_to_serialize.present?
          record_hash
        else
          record_hash                 = id_hash(id_from_record(record), record_type, true)
          record_hash[:attributes]    = attributes_hash(record, fieldset, params) if attributes_to_serialize.present?
          record_hash[:relationships] = relationships_hash(record, nil, fieldset, params) if relationships_to_serialize.present?
          record_hash[:links]         = links_hash(record, params) if data_links.present?
          record_hash[:meta]          = meta_hash(record, params) if meta_to_serialize.present?
          record_hash
        end
      end

      def id_from_record(record)
        return record_id.call(record) if record_id.is_a?(::Proc)
        return record.send(record_id) if record_id
        raise MandatoryField, 'id is a mandatory field in the jsonapi spec' unless record.respond_to?(:id)
        record.id
      end

      # Override #to_json for alternative implementation
      def to_json(payload)
        Oj.dump(payload, mode: :compat, time_format: :ruby) if payload.present?
      end

      def parse_include_item(include_item)
        return [include_item.to_sym] unless include_item.to_s.include?('.')
        include_item.to_s.split('.').map { |item| item.to_sym }
      end

      def remaining_items(items)
        return unless items.size > 1

        items_copy = items.dup
        items_copy.delete_at(0)
        [items_copy.join('.').to_sym]
      end

      # includes handler
      def get_included_records(record, includes_list, known_included_objects, fieldsets, params = {})
        return unless includes_list.present?

        includes_list.sort.each_with_object([]) do |include_item, included_records|
          items = parse_include_item(include_item)
          items.each do |item|
            next unless relationships_to_serialize && relationships_to_serialize[item]
            relationship_item = relationships_to_serialize[item]
            next unless relationship_item.include_relationship?(record, params)

            polymorphic_hash = relationship_item.polymorphic.is_a?(::Hash) ? relationship_item.polymorphic : nil

            unless polymorphic_hash
              record_type = relationship_item.record_type
              serializer  = relationship_item.serializer.to_s.constantize
            end
            relationship_type = relationship_item.relationship_type

            included_objects = relationship_item.fetch_associated_object(record, params)
            next if included_objects.blank?
            included_objects = [included_objects] unless relationship_type == :has_many

            included_objects.each do |inc_obj|
              if polymorphic_hash
                record_type = polymorphic_hash[inc_obj.class]
                serializer  = self.compute_serializer_name(record_type.to_s.underscore.to_sym).to_s.constantize
              end

              if remaining_items(items)
                serializer_records = serializer.get_included_records(inc_obj, remaining_items(items), known_included_objects, fieldsets, params)
                included_records.concat(serializer_records) unless serializer_records.empty?
              end

              code = "#{record_type}_#{serializer.id_from_record(inc_obj)}"
              next if known_included_objects.key?(code)

              known_included_objects[code] = inc_obj

              included_records << serializer.record_hash(inc_obj, fieldsets[serializer.record_type], params)
            end
          end
        end
      end
    end
  end
end