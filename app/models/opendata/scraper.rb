class Opendata::Scraper
  include SS::Document

  field :source_url, type: String
  field :dataset_urls, type: Array
  validates :source_url, presence: true

  def get_dataset_urls
    path = "dataset/search/index.p:page.html"

    urls = []
    1.upto(1000) do |count|
      url = File.join(source_url, path.sub(':page', count.to_s))
      puts url

      f = open(url)
      html = f.read
      charset = f.charset

      doc = Nokogiri::HTML.parse(html, nil, charset)
      links = doc.css('.opendata-search-datasets.pages article h2 a')
      break if links.blank?

      links.each do |link|
        href = link.attributes["href"]
        next if href.blank?
        urls << href.value
      end
    end
    urls
  end

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

