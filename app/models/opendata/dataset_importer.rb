require 'open-uri'

class Opendata::DatasetImporter
  include SS::Document
  include SS::Reference::User
  include SS::Reference::Site
  include Cms::Reference::Node
  include Cms::Addon::GroupPermission
  include ActiveSupport::NumberHelper

  set_permission_name "opendata_datasets"

  seqid :id

  field :api_type, type: String
  field :source_url, type: String
  field :order, type: Integer, default: 0

  validates :api_type, presence: true
  validates :source_url, presence: true

  permit_params :api_type, :source_url, :order

  default_scope -> { order_by(order: 1) }

  def order
    value = self[:order].to_i
    value < 0 ? 0 : value
  end

  def api_type_options
    [
      ["Ckan API", "ckan"],
      ["Shirasagi API", "shirasagi"],
    ]
  end

  def import
    if api_type == "ckan"
      import_from_ckan_api
    elsif api_type == "shirasagi"
      import_from_shirasagi_api
    end
  end

  def import_from_ckan_api
    Rails.logger.warn("import from #{source_url} (Ckan API)")

    package = Ckan::Package.new(source_url)

    imported_dataset_ids = []
    list = package.package_list
    list.each do |name|
      begin
        Rails.logger.warn("- #{name}")
        dataset_attributes = package.package_show(name)
      rescue => e
        Rails.logger.warn("#{e.class} (#{e.message}):\n  #{e.backtrace.join("\n  ")}")
        next
      end

      begin
        dataset = import_dataset_from_ckan_api(dataset_attributes)
        imported_dataset_ids << dataset.id
      rescue => e
        Rails.logger.error("#{e.class} (#{e.message}):\n  #{e.backtrace.join("\n  ")}")
        next
      end

      license = Opendata::License.site(site).where(
        ckan_license_id: dataset_attributes["license_id"].to_s
      ).first
      Rails.logger.warn("could not found license #{ckan_license_id}") if license.nil?

      imported_resource_ids = []
      dataset_attributes["resources"].each do |resource_attributes|
        begin
          resource = import_resource_from_ckan_api(resource_attributes, dataset, license)
        rescue => e
          Rails.logger.error("#{e.class} (#{e.message}):\n  #{e.backtrace.join("\n  ")}")
          next
        end

        imported_resource_ids << resource.id
      end

      # destroy unimported resources
      dataset.resources.each do |resource|
        next if imported_resource_ids.include?(resource.id)
        Rails.logger.warn("-- resource : destroy #{resource.name}")
        resource.destroy
      end
    end

    # destroy unimported datasets
    dataset_ids = Opendata::Dataset.site(site).node(node).where(
      "importer_attributes.api_type" => api_type,
      "importer_attributes.source_url" => source_url,
    ).pluck(:id)
    dataset_ids = dataset_ids - imported_dataset_ids
    dataset_ids.each do |id|
      dataset = Opendata::Dataset.find(id) rescue nil
      next unless dataset

      Rails.logger.warn("-- dataset : destroy #{dataset.name}")
      dataset.destroy
    end
  end

  def import_dataset_from_ckan_api(attributes)
    dataset = Opendata::Dataset.node(node).where(uuid: attributes["id"]).first
    dataset ||= Opendata::Dataset.new

    dataset.cur_site = site
    dataset.cur_node = node
    dataset.layout = node.page_layout || node.layout
    dataset.uuid = attributes["id"]
    dataset.name = attributes["title"]
    dataset.text = attributes["notes"]
    dataset.group_ids = group_ids

    dataset.imported = Time.zone.now
    dataset.imported_attributes = attributes
    dataset.importer_attributes = self.attributes

    Rails.logger.warn("-- dataset : #{dataset.new_record? ? "create" : "update"} #{dataset.name}")

    dataset.save!
    dataset
  end

  def import_resource_from_ckan_api(attributes, dataset, license)
    resource = dataset.resources.select { |r| r.uuid == attributes["id"] }.first
    resource ||= Opendata::Resource.new

    if resource.revision_id == attributes["revision_id"]
      Rails.logger.warn("-- resource : skip #{resource.name}")
      return resource
    end

    filename = attributes["name"] + ::File.extname(attributes["url"])

    Rails.logger.warn("-- resource : open file #{filename} (#{attributes["url"]})")
    mb = 100_000_000
    file = open(attributes["url"], read_timeout: 20,
      progress_proc: ->(size) do
        print "\r-- resource : open file #{filename} #{number_to_human_size(size)}"
      end
    )
    file.instance_variable_set("@_original_filename", filename)
    def file.original_filename
      @_original_filename
    end
    def file.content_type
      ::Fs.content_type(path)
    end

    ss_file = resource.file
    ss_file ||= SS::File.new
    ss_file.in_file = file
    ss_file.model = "opendata/resource"
    ss_file.state = "public"
    ss_file.site_id = site.id
    ss_file.send(:set_filename)
    ss_file.save(validate: false)
    ss_file.reload

    resource.file_id = ss_file.id
    resource.format = ::File.extname(attributes["url"]).delete(".")

    resource.uuid = attributes["id"]
    resource.revision_id = attributes["revision_id"]
    resource.name = attributes["name"]
    resource.filename = filename
    resource.license = license

    resource.imported = Time.zone.now
    resource.imported_attributes = attributes
    resource.importer_attributes = self.attributes

    Rails.logger.warn("-- resource : #{resource.new_record? ? "create" : "update"} #{resource.name}")

    dataset.resources << resource
    resource.save!

    file.close
    resource
  end

  def import_from_shirasagi_api
    #
  end
end

