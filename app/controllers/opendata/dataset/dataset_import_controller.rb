class Opendata::Dataset::DatasetImportController < ApplicationController
  include Cms::BaseFilter
  include Cms::CrudFilter

  helper Opendata::FormHelper

  model Opendata::DatasetImport::Importer

  navi_view "opendata/main/navi"

  def fix_params
    { cur_user: @cur_user, cur_site: @cur_site, cur_node: @cur_node }
  end

  def index
    @items = Opendata::DatasetImport::Importer.site(@cur_site).node(@cur_node)
      .allow(:read, @cur_user, site: @cur_site)
  end
end
