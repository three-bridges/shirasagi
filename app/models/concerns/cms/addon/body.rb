module Cms::Addon
  module Body
    extend ActiveSupport::Concern
    extend SS::Addon

    included do
      field :html, type: String
      field :markdown, type: String
      field :contains_urls, type: Array, default: []
      permit_params :html, :markdown

      before_validation :set_contains_urls

      if respond_to?(:template_variable_handler)
        template_variable_handler('img.src', :template_variable_handler_img_src)
        template_variable_handler('thumb.src', :template_variable_handler_thumb_src)
      end
    end

    def html
      if SS.config.cms.html_editor == "markdown"
        Kramdown::Document.new(markdown.to_s, input: 'GFM').to_html
      else
        self[:html]
      end
    end

    def mobile_size_enable?
      self.site.mobile_enabled?
    end

    def mobile_size
      self.site.mobile_size
    end

    private

    def set_contains_urls
      return if html.blank?
      self.contains_urls = html.scan(/(?:href|src)="(.*?)"/).flatten.uniq
    end

    def template_variable_handler_img_src(name, issuer)
      extract_img_src(html) || default_img_src
    end

    def template_variable_handler_thumb_src(name, issuer)
      thumb_path || extract_img_src(html) || default_img_src
    end

    def default_img_src
      ERB::Util.html_escape("/assets/img/dummy.png")
    end

    def extract_img_src(html)
      return nil unless html =~ /\<\s*?img\s+[^>]*\/?>/i

      img_tag = $&
      return nil unless img_tag =~ /src\s*=\s*(['"]?[^'"]+['"]?)/

      img_source = $1
      img_source = img_source[1..-1] if img_source.start_with?("'", '"')
      img_source = img_source[0..-2] if img_source.end_with?("'", '"')
      img_source = img_source.strip
      if img_source.start_with?('.') && respond_to?(:url)
        # convert relative path to absolute path
        img_source = ::File.dirname(url) + '/' + img_source
      end
      img_source
    end

    def thumb_path
      "/fs/#{thumb.id}/#{thumb.filename}" if thumb.present?
    end
  end
end
