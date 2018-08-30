module Opendata::Addon::DatasetImport::Dataset
  extend SS::Addon
  extend ActiveSupport::Concern

  included do
    field :uuid, type: String, default: nil
    field :imported, type: DateTime, default: nil
    field :imported_attributes, type: Hash, default: nil
    field :importer_attributes, type: Hash , default: nil

    before_validation :set_uuid
    validates :uuid, presence: true
  end

  def set_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
