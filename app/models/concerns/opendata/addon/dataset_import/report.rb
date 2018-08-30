module Opendata::Addon::DatasetImport::Report
  extend SS::Addon
  extend ActiveSupport::Concern

  def report
    if api_type == "ckan"
      report_from_ckan_api
    elsif api_type == "shirasagi_api"
      report_from_shirasagi_api
    elsif api_type == "shirasagi_scraper"
      report_from_shirasagi_scraper
    end
  end

  def get_size_in_head(url)
    conn = ::Faraday::Connection.new(url: url)
    res = conn.head { |req| req.options.timeout = 10 }
    raise "Faraday conn.head timeout #{url}" unless res.success?

    headers = res.headers.map { |k, v| [k.downcase, v] }.to_h

    size = 0
    if headers["content-length"]
      size = headers["content-length"].to_i
    elsif headers["content-range"]
      size = headers["content-range"].scan(/\/(\d+)$/).flatten.first.to_i
    end

    size
  end

  def report_from_ckan_api
    report = ::Opendata::DatasetImport::Report.new
    report.cur_site = site
    report.cur_node = node
    report.importer = self
    report.save!

    Rails.logger.warn("report from #{source_url} (Ckan API)")
    puts "report from #{source_url} (Ckan API)"

    package = ::Opendata::DatasetImport::Ckan::Package.new(source_url)
    list = package.package_list

    Rails.logger.warn("package_list #{list.size}")
    puts "package_list #{list.size}"

    list.each_with_index do |name, idx|
      begin
        report_dataset = ::Opendata::DatasetImport::ReportDataset.new
        report_dataset.report = report
        report_dataset.order = idx

        Rails.logger.warn("- #{idx + 1} #{name}")
        puts "- #{idx + 1} #{name}"

        dataset_attributes = package.package_show(name)

        report_dataset.source_attributes = dataset_attributes
        report_dataset.url = dataset_attributes["url"]
        report_dataset.name = dataset_attributes["title"]

        ckan_license_id = dataset_attributes["license_id"]
        license = ::Opendata::License.site(site).where(
          ckan_license_id: ckan_license_id.to_s
        ).first

        if license.nil?
          Rails.logger.warn("could not found license #{ckan_license_id}")
          report_dataset.error_messages << "could not found license #{ckan_license_id}"
        end

        dataset_attributes["resources"].each_with_index do |resource_attributes, idx|
          begin
            puts "-- resouce #{idx + 1}"
            Rails.logger.warn("-- resouce #{idx + 1}")

            report_resource = ::Opendata::DatasetImport::ReportResource.new
            report_resource.source_attributes = resource_attributes
            report_resource.url = resource_attributes["url"]
            report_resource.name = resource_attributes["name"]
            report_resource.format = resource_attributes["format"].downcase
            report_resource.filename = resource_attributes["name"] + "." + report_resource.format
            report_resource.order = idx
            report_resource.size = get_size_in_head(report_resource.url) rescue 0

            if report_resource.size == 0
              report_dataset.error_messages << "resouce#{idx + 1} #{report_resource.name} : could not fetch size"
            end
          rescue => e
            Rails.logger.warn("#{e.class} (#{e.message}):\n  #{e.backtrace.join("\n  ")}")
            report_dataset.error_messages << "#{e.class} (#{e.message}):\n  #{e.backtrace.join("\n  ")}"
          ensure
            report_dataset.resources << report_resource
          end
        end
      rescue => e
        Rails.logger.warn("#{e.class} (#{e.message}):\n  #{e.backtrace.join("\n  ")}")
        report_dataset.error_messages << "#{e.class} (#{e.message}):\n  #{e.backtrace.join("\n  ")}"
      ensure
        report_dataset.save!
      end
    end

    report.save!
  end

  def report_from_shirasagi_scraper
    report = ::Opendata::DatasetImport::Report.new
    report.cur_site = site
    report.cur_node = node
    report.importer = self
    report.save!

    Rails.logger.warn("report from #{source_url} (SHIRASAGI scraper)")
    puts "report from #{source_url} (SHIRASAGI scraper)"

    package = ::Opendata::DatasetImport::SS::Scraper.new(source_url)

    urls = package.get_dataset_urls
    Rails.logger.warn("dataset_urls #{urls.size}")
    puts "dataset_urls #{urls.size}"

    urls.each_with_index do |url, idx|
      begin
        report_dataset = ::Opendata::DatasetImport::ReportDataset.new
        report_dataset.report = report
        report_dataset.order = idx

        Rails.logger.warn("- #{idx + 1} #{url}")
        puts "- #{idx + 1} #{url}"

        dataset_attributes = package.get_dataset(url)

        report_dataset.source_attributes = dataset_attributes
        report_dataset.url = dataset_attributes["url"]
        report_dataset.name = dataset_attributes["title"]

        dataset_attributes["resources"].each_with_index do |resource_attributes, idx|
          begin
            puts "-- resouce #{idx + 1}"
            Rails.logger.warn("-- resouce #{idx + 1}")

            report_resource = ::Opendata::DatasetImport::ReportResource.new
            report_resource.source_attributes = resource_attributes
            report_resource.url = resource_attributes["url"]
            report_resource.name = resource_attributes["name"]
            report_resource.filename = resource_attributes["filename"]
            report_resource.format = resource_attributes["format"]
            report_resource.order = idx

            report_resource.size = resource_attributes["display_size"]

            if report_resource.size == 0
              report_dataset.error_messages << "resouce#{idx + 1} #{report_resource.name} : could not fetch size"
            end
          rescue => e
            Rails.logger.warn("#{e.class} (#{e.message}):\n  #{e.backtrace.join("\n  ")}")
            report_dataset.error_messages << "#{e.class} (#{e.message}):\n  #{e.backtrace.join("\n  ")}"
          ensure
            report_dataset.resources << report_resource
          end
        end

      rescue => e
        Rails.logger.warn("#{e.class} (#{e.message}):\n  #{e.backtrace.join("\n  ")}")
        report_dataset.error_messages << "#{e.class} (#{e.message}):\n  #{e.backtrace.join("\n  ")}"
      ensure
        report_dataset.save!
      end
    end

    report.save!
  end
end
