# frozen_string_literal: true

require 'spec_helper'

describe FastJsonapi::ObjectSerializer do
  class List
    attr_accessor :id, :name, :items
  end

  class ChecklistItem
    attr_accessor :id, :name
  end

  class Car
    attr_accessor :id, :model, :year
  end

  class BaseListSerializer
    include ::FastJsonapi::ObjectSerializer
    set_type :list
    attributes :name
    set_key_transform :dash
  end

  class PolymorphicHashListSerializer < BaseListSerializer
    has_many :items, polymorphic: { ChecklistItem => :'checklist-item-override', Car => :'car-override' }
  end

  class PolymorphicListSerializer < BaseListSerializer
    has_many :items, polymorphic: true
  end

  class BaseChecklistItemSerializer
    include ::FastJsonapi::ObjectSerializer
    set_type :checklist_item
    set_key_transform :dash

    attributes :id, :name
  end

  class ChecklistItemSerializer < BaseChecklistItemSerializer
  end

  class ChecklistItemOverrideSerializer < BaseChecklistItemSerializer
  end

  class BaseCarSerializer
    include ::FastJsonapi::ObjectSerializer
    set_type :car
    set_key_transform :dash

    attributes :id, :model, :year
  end

  class CarSerializer < BaseCarSerializer
  end

  class CarOverrideSerializer < BaseCarSerializer
  end

  let(:car) do
    car       = Car.new
    car.id    = 1
    car.model = 'Toyota Corolla'
    car.year  = 1987
    car
  end

  let(:checklist_item) do
    checklist_item      = ChecklistItem.new
    checklist_item.id   = 2
    checklist_item.name = 'Do this action!'
    checklist_item
  end

  context 'when serializing id and type of polymorphic relationships' do
    it 'should return correct type when transform_method is specified' do
      list       = List.new
      list.id    = 1
      list.items = [checklist_item, car]
      list_hash  = PolymorphicListSerializer.new(list, { include: [:items] }).to_hash
      record_type = list_hash[:data][:relationships][:items][:data][0][:type]
      expect(record_type).to eq 'checklist-item'.to_sym
      record_type = list_hash[:data][:relationships][:items][:data][1][:type]
      expect(record_type).to eq 'car'.to_sym

      list_hash  = PolymorphicHashListSerializer.new(list, { include: [:items] }).to_hash
      record_type = list_hash[:data][:relationships][:items][:data][0][:type]
      expect(record_type).to eq 'checklist-item-override'.to_sym
      record_type = list_hash[:data][:relationships][:items][:data][1][:type]
      expect(record_type).to eq 'car-override'.to_sym
    end
  end
end
