# encoding: utf-8
# Order of method calls
#  download_files
#  store_translations
#  clean_up
#
require 'roo'

module LocalchI18n
  class Translations

    attr_accessor :locales, :tmp_folder, :config_file, :csv_files

    def initialize(config_file = nil, tmp_folder = nil)
      @config_file = config_file
      @tmp_folder  = tmp_folder

      @csv_files = {}

      load_config
      load_locales
    end

    def load_locales
      @locales = []
      @locales = I18n.available_locales if defined?(I18n)
    end

    def load_config
      @settings = {}
      @settings = YAML.load_file(config_file) if File.exists?(config_file)
    end

    # New version of download_files
    # Now uses the google docs api to fetch the files
    # It enforces OAuth2
    def download_files
      files = @settings['files']
      gd = GoogleDownloader.new @settings

      files.each do |target_file, file_id|
        target_file = target_file + ".yml" if target_file !~ /\.yml$/
        response = gd.download target_file, @tmp_folder, file_id
        @csv_files[target_file] = csv_convert(target_file)
      end
    end

    def csv_convert target_file
      source = File.join(@tmp_folder, target_file.gsub(".yml", ".xlsx"))
      dest = File.join(@tmp_folder, target_file)

      sheet = Roo::Excelx.new source
      sheet.to_csv dest
      dest
    end

    def store_translations
      @csv_files.each do |target_file, csv_file|
        converter = CsvToYaml.new(csv_file, target_file, @locales)
        converter.process
        converter.write_files
      end

      @csv_files
    end

    def clean_up
      # remove all tmp files
      @csv_files.each do |target_file, csv_file|
        File.unlink(csv_file)
        File.unlink(File.join(@tmp_folder, target_file.gsub(".yml", ".xlsx")))
      end
    end

    def download(url, destination_file)
      puts "Download '#{url}' to '#{destination_file}'"
      doc_data = open(url).read.force_encoding('UTF-8')
      File.open(destination_file, 'w') do |dst|
        dst.write(doc_data)
      end
    end

  end
end
