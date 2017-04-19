describe Fastlane do
  describe Fastlane::FastFile do
    describe "Mobile Center Integration" do
      before :each do
        allow(FastlaneCore::FastlaneFolder).to receive(:path).and_return(nil)
      end

      it "raises an error if no api token was given" do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            mobile_center_upload({
              owner_name: 'owner',
              app_name: 'app',
              group: 'Testers',
              file: './fastlane/spec/fixtures/fastfiles/Fastfile1'
            })
          end").runner.execute(:test)
        end.to raise_error("No API token for Mobile Center given, pass using `api_token: 'token'`")
      end

      it "raises an error if no owner name was given" do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            mobile_center_upload({
              api_token: 'xxx',
              app_name: 'app',
              group: 'Testers',
              file: './fastlane/spec/fixtures/fastfiles/Fastfile1'
            })
          end").runner.execute(:test)
        end.to raise_error("No Owner name for Mobile Center given, pass using `owner_name: 'name'`")
      end

      it "raises an error if no app name was given" do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            mobile_center_upload({
              api_token: 'xxx',
              owner_name: 'owner',
              group: 'Testers',
              file: './fastlane/spec/fixtures/fastfiles/Fastfile1'
            })
          end").runner.execute(:test)
        end.to raise_error("No App name given, pass using `app_name: 'app name'`")
      end

      it "raises an error if no group was given" do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            mobile_center_upload({
              api_token: 'xxx',
              owner_name: 'owner',
              app_name: 'app',
              file: './fastlane/spec/fixtures/fastfiles/Fastfile1'
            })
          end").runner.execute(:test)
        end.to raise_error("No Distribute Group given, pass using `group: 'group name'`")
      end

      it "raises an error if no build file was given" do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            mobile_center_upload({
              api_token: 'xxx',
              owner_name: 'owner',
              app_name: 'app',
              group: 'Testers'
            })
          end").runner.execute(:test)
        end.to raise_error("Couldn't find build file at path ''")
      end

      it "raises an error if given file was not found" do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            mobile_center_upload({
              api_token: 'xxx',
              owner_name: 'owner',
              app_name: 'app',
              group: 'Testers',
              file: './nothing.apk'
            })
          end").runner.execute(:test)
        end.to raise_error("Couldn't find build file at path './nothing.apk'")
      end

      it "works with valid parameters" do
        stub_request(:post, "https://api.mobile.azure.com/v0.1/apps/owner/app/release_uploads")
          .with(
            body: "{}",
            headers: {
              'Accept' => '*/*',
              'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
              'Content-Type' => 'application/json',
              'User-Agent' => 'Faraday v0.12.0.1',
              'X-Api-Token' => 'xxx'
            }
          )
          .to_return(
            status: 200,
            body: "{\"upload_id\":\"upload_id\",\"upload_url\":\"https://upload.com\"}",
            headers: { 'Content-Type' => 'application/json' }
          )

        stub_request(:post, "https://upload.com/")
          .to_return(status: 200, body: "", headers: {})

        stub_request(:patch, "https://api.mobile.azure.com/v0.1/apps/owner/app/release_uploads/upload_id")
          .with(
            body: "{\"status\":\"committed\"}",
            headers: {
              'Accept' => '*/*',
              'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
              'Content-Type' => 'application/json', 'User-Agent' => 'Faraday v0.12.0.1',
              'X-Api-Token' => 'xxx'
            }
          )
          .to_return(status: 200, body: "{\"release_url\":\"v0.1/apps/owner/app/releases/1\"}", headers: {})

        stub_request(:patch, "https://api.mobile.azure.com/release_url")
          .with(
            body: "{\"distribution_group_name\":\"Testers\",\"release_notes\":null}",
            headers: {
              'Accept' => '*/*',
              'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
              'Content-Type' => 'application/json',
              'User-Agent' => 'Faraday v0.12.0.1',
              'X-Api-Token' => 'xxx'
            }
          )
          .to_return(status: 200, body: "{\"short_version\":\"1.0\"}", headers: { 'Content-Type' => 'application/json' })

        Fastlane::FastFile.new.parse("lane :test do
          mobile_center_upload({
            api_token: 'xxx',
            owner_name: 'owner',
            app_name: 'app',
            file: './fastlane/spec/fixtures/appfiles/Appfile_empty',
            group: 'Testers'
          })
        end").runner.execute(:test)
      end
    end
  end
end
