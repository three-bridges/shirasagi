module Opendata::DatasetImport
  class Report
    include SS::Document
    include SS::Reference::Site
    include Cms::Reference::Node

    store_in collection: 'opendata_dataset_importer_reports'

    field :size, type: Integer, default: 0
    belongs_to :importer, class_name: 'Opendata::DatasetImport::Importer'
    has_many :datasets, class_name: 'Opendata::DatasetImport::ReportDataset', dependent: :destroy, inverse_of: :report

    before_validation :set_size

    def set_size
      self.size = datasets.pluck(:size).sum
    end
  end

  class ReportDataset
    include SS::Document

    store_in collection: 'opendata_dataset_importer_report_datasets'

    belongs_to :report, class_name: 'Opendata::DatasetImport::Report'
    embeds_many :resources, class_name: 'Opendata::DatasetImport::ReportResource'

    field :order, type: Integer
    field :size, type: Integer, default: 0

    field :url, type: String
    field :name, type: String

    field :uuid, type: String
    field :revision_id, type: String

    field :source_attributes, type: Hash

    field :error_messages, type: Array, default: []

    before_validation :set_size

    def set_size
      self.size = resources.pluck(:size).sum
    end
  end

  class ReportResource
    include SS::Document

    embedded_in :dataset, class_name: 'Opendata::DatasetImport::ReportDataset', inverse_of: :resources

    field :order, type: Integer
    field :size, type: Integer, default: 0

    field :url, type: String
    field :name, type: String

    field :uuid, type: String
    field :revision_id, type: String

    field :filename, type: String
    field :format, type: String

    field :source_attributes, type: Hash
  end
end
