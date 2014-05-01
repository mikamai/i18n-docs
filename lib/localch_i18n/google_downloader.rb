require "rubygems"
require "google/api_client"
require "json"

module LocalchI18n
  class GoogleDownloader
    def initialize settings = {}
      @client = Google::APIClient.new(
        application_name: settings["application"]["name"],
        application_version: settings["application"]["version"]
      )

      key = Google::APIClient::KeyUtils.load_from_pkcs12 Base64.urlsafe_decode64(settings["application"]["pkcs12"]), 'notasecret'

      @client.authorization = Signet::OAuth2::Client.new(
        token_credential_uri: "https://accounts.google.com/o/oauth2/token",
        audience: "https://accounts.google.com/o/oauth2/token",
        scope: "https://www.googleapis.com/auth/drive",
        issuer: settings["application"]["issuer"],
        signing_key: key
      )

      @client.authorization.fetch_access_token!
      @drive = @client.discovered_api 'drive', 'v2'
    end

    def download target_file, tmp_folder, file_id
      base = get_metadata file_id
      return nil unless base["exportLinks"]
      result = @client.execute uri: base["exportLinks"]["application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"]

      if result.status == 200
        File.open File.join(tmp_folder, target_file.gsub(/yml$/, "xlsx")), "wb" do |f|
          f.write result.body
        end
      end
    end

    def get_metadata file_id
      response = @client.execute api_method: @drive.files.get, parameters: {'fileId' => file_id}
      if response.status == 200
        JSON.parse(response.body)
      else
        { status: response.status }
      end
    end
  end
end
