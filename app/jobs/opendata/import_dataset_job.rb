class Opendata::ImportDatasetJob < Cms::ApplicationJob
  def put_log(message)
    Rails.logger.warn(message)
  end

  def perform(*args)
    Opendata::DatasetImport::Importer.site(site).each do |importer|
      importer.import
    end
  end
end
