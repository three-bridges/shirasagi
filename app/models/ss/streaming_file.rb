class SS::StreamingFile
  include SS::Model::File
  include SS::Relation::Thumb

  attr_accessor :in_remote_url

  before_validation :set_filename, if: ->{ in_remote_url.present? }

  validates_with SS::FileSizeValidator, if: ->{ false }

  before_save :save_file

  def set_filename
    uri = ::URI.parse(in_remote_url)
    basename = ::File.basename(uri.path)
    self.name = basename if self[:name].blank?
    self.filename = basename if filename.blank?
    #self.size
    #self.content_type
  end

  # not implemented save_file for grid-fs mode
  def save_file
    return if in_remote_url.blank?

    Fs.mkdir_p(::File.dirname(path))
    fin = ::Down.open(in_remote_url)
    print "download #{in_remote_url}\n"

    size = 0
    open(path, "wb") do |fout|
     fin.each_chunk do |chunk|
       size += chunk.size
        print "#{number_to_human_size(size)}\r"
        fout.write chunk
      end
    end

    self.content_type = ::SS::MimeType.find(::File.basename(path), fin.data.dig(:headers, "Content-Type"))
    self.size = Fs.stat(path).size

    print "#{number_to_human_size(self.size)}\n"
    fin.close

    #if image?
    #  list = Magick::ImageList.new
    #  list.from_blob(path)
    #  extract_geo_location(list)
    #  list.each do |image|
    #    case SS.config.env.image_exif_option
    #    when "auto_orient"
    #      image.auto_orient!
    #    when "strip"
    #      image.strip!
    #    end
    #  end
    #  Fs.binwrite path, list.to_blob
    #end
  end
end
