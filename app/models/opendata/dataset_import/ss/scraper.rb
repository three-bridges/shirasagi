module Opendata::DatasetImport::SS
  class Scraper
    attr_accessor :url

    public

    def initialize(url, dataset_search_path = "dataset/search")
      @url = url
      @dataset_search_path = dataset_search_path
      @max_pagination = 10000
    end

    def dataset_search_url
      ::File.join(url, @dataset_search_path, "index.p:page.html")
    end

    def get_dataset_urls
      urls = []
      1.upto(@max_pagination) do |count|
        search_url = dataset_search_url.sub(':page', count.to_s)
        puts search_url

        f = open(search_url, read_timeout: 20)
        html = f.read
        #charset = f.charset
        charset = "utf-8"

        doc = Nokogiri::HTML.parse(html, nil, charset)
        links = doc.css('.opendata-search-datasets.pages article h2 a')
        break if links.blank?

        links.each do |link|
          href = link.attributes["href"]
          next if href.blank?
          urls << ::File.join(url, href.value)
        end
      end
      urls
    end

    def get_dataset(dataset_url)
      dataset = {}

      f = open(dataset_url, read_timeout: 20)
      html = f.read
      #charset = f.charset
      charset = "utf-8"

      doc = Nokogiri::HTML.parse(html, nil, charset)

      dataset["title"] = doc.css('#main h1.name').text.to_s.strip
      dataset["notes"] = doc.css('#main .categories + .text').text.to_s.strip
      dataset["license_title"] = doc.css('#main .license img').first.attributes["alt"].value rescue nil
      dataset["categories"] = doc.css("#main .categories .category").map { |node| node.text.to_s.strip }
      dataset["areas"] = doc.css("#main .categories .area").map { |node| node.text.to_s.strip }

      dataset["resources"] = doc.css("#main .resources .resource").map do |node|
        resource = {}
        resource["name"] = node.css(".info .name").text.to_s.strip
        resource["url"] = node.css(".icons a.download").first.attributes["href"].value rescue nil
        resource["filename"] = ::File.basename(resource["url"]) rescue nil
        resource["format"] = ::File.extname(resource["url"]) rescue nil

        if resource["name"].present?
          digits = %w(バイト KB MB GB TB PB)
          bytes, digit = resource["name"].scan(/ ([\d\.]+?)(#{digits.join("|")})\)$/).flatten

          if digits.index(digit)
            resource["display_size"] = (bytes.to_f * (1024 ** digits.index(digit))).to_i
          end
        end

        resource
      end.select { |resource| resource["url"].present? }

      dataset
    end

=begin
    def get_dataset_list
      CSV.generate do |data|
        data << %w(title notes license_title resources groups organization url)

        dataset_urls.each do |url|
          url = File.join(source_url, url)

          f = open(url)
          html = f.read
          charset = "utf-8"
          doc = Nokogiri::HTML.parse(html, nil, charset)

          title = doc.css('#main h1.name').text.to_s.strip
          notes = doc.css('#main .categories + .text').text.to_s.strip
          license_title = doc.css('#main .license img').first.attributes["alt"].value rescue nil
          resources = doc.css("#main .resources .resource .info .name").map { |node| node.text.to_s.strip }.join("\n")
          groups = doc.css("#main .categories .category").map { |node| node.text.to_s.strip }.join("\n")
          organization = doc.css("#main .categories .area").map { |node| node.text.to_s.strip }.join("\n")

          line = []
          line << title
          line << notes
          line << license_title
          line << resources
          line << groups
          line << organization
          line << url

          p line

          data << line
        end
      end
    end
  end
=end
  end
end



