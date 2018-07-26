module Ckan
  class Package
    include SS::Document

    field :source_url, type: String
    validates :source_url, presence: true

    def package_list_url
      ::File.join(source_url, "api/action/package_list")
    end

    def package_show_url
      ::File.join(source_url, "api/action/package_show")
    end

    def package_list
      json = open(package_list_url).read
      ::JSON.parse(json)
    end

    def package_show(id)
      json = open(package_show_url + "?id=#{id}").read
      ::JSON.parse(json)
    end

    def package_list_to_csv
      list = package_list["result"]
      CSV.generate do |data|
        data << %w(title notes license_title resources groups organization url)

        list.each do |id|
          puts id
          package = package_show(id)["result"]
          line = []
          line << package["title"]
          line << package["notes"]
          line << package["license_title"]
          line << package["resources"].map { |resources| resources["name"] }.join("\n")
          line << package["groups"].map { |resources| resources["title"] }.join("\n")
          line << package.dig("organization", "title")
          line << ::File.join(source_url, "/dataset/#{id}")
          data << line
        end
      end
    end
  end
end
