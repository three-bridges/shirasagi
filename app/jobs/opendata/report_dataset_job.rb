class Opendata::ReportDatasetJob < Cms::ApplicationJob
  def put_log(message)
    Rails.logger.warn(message)
  end

  def perform(importer_id)
    importer = Opendata::DatasetImport::Importer.find(importer_id)
    p importer
    importer.report
  end
end
