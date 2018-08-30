class Opendata::Dataset::DatasetImportReportsController < ApplicationController
  include Cms::BaseFilter
  include Cms::CrudFilter

  model Opendata::DatasetImport::Report

  navi_view "opendata/main/navi"

  def fix_params
    {}
  end

  def show
  end

  def dataset
    @item = Opendata::DatasetImport::ReportDataset.find(params[:dataset_id])
  end
end
