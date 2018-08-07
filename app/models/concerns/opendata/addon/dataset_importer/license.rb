module Opendata::Addon::DatasetImporter::License
  extend SS::Addon
  extend ActiveSupport::Concern

  included do
    field :ckan_license_id, type: String, default: nil
    permit_params :ckan_license_id
  end
end
