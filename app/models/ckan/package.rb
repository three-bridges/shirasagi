module Ckan
  class Package
    attr_accessor :url

    private

    def validate_package_list(result)
      raise "get package_list failed : not success" if result["success"] != true
      raise "get package_list failed : result not found" if result["result"].nil?
    end

    def validate_package_show(id, result)
      raise "get package_show #{id} failed : not success" if result["success"] != true
      raise "get package_show #{id} failed : result not found" if result["result"].nil?

      result = result["result"]
      raise "get package_show #{id} failed : uuid not found" if result["id"].nil?

      resources = result["resources"]
      return if resources.blank?
      resources.each do |resource|
        raise "get package_show #{id} failed : resource uuid not found" if resource["id"].nil?
      end
    end

    public

    def initialize(url)
      @url = url
    end

    def package_list_url
      ::File.join(url, "api/action/package_list")
    end

    def package_show_url
      ::File.join(url, "api/action/package_show")
    end

    def package_list
      result = open(package_list_url, read_timeout: 20).read
      result = ::JSON.parse(result)
      validate_package_list(result)
      result["result"]
    end

    def package_show(id)
      result = open(package_show_url + "?id=#{id}", read_timeout: 20).read
      result = ::JSON.parse(result)
      validate_package_show(id, result)
      result["result"]
    end

    def package_list_to_csv
      list = package_list
      CSV.generate do |data|
        data << %w(title notes license_title resources groups organization url)

        list.each do |id|
          puts id
          package = package_show(id)
          line = []
          line << package["title"]
          line << package["notes"]
          line << package["license_title"]
          line << package["resources"].map { |resources| resources["name"] }.join("\n")
          line << package["groups"].map { |resources| resources["title"] }.join("\n")
          line << package.dig("organization", "title")
          line << ::File.join(url, "/dataset/#{id}")
          data << line
        end
      end
    end
  end
end
