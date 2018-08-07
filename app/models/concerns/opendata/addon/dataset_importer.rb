module Opendata::Addon::DatasetImporter
  extend SS::Addon
  extend ActiveSupport::Concern
  include Opendata::CmsRef::Page

  included do
    field :ckan_id, type: String
    field :source_url, type: String
  end
end
