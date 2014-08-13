# http://files.zimbra.com/docs/soap_api/8.0.4/soap-docs-804/api-reference/zimbraMail/GetFolder.html
module Zimbra
  class Message
    class << self
      def create(upload_id, folder_path, flags=nil, timestamp=nil, tags=nil)
        MessageService.create(upload_id, folder_path, flags, timestamp, tags)
      end
    end
  end
  
  class MessageService < HandsoapAccountService
    # Create a new message
    def create(path, folder_path, flags, timestamp, tags)
      upload_id = upload(path)
      xml = invoke ("n2:AddMsgRequest") do |message|
        Builder.create(message, upload_id, folder_path, flags, timestamp, tags)
      end
    end 

    # Upload a message
    def upload(path)

      # base url of upload service
      base_uri=URI.parse(Zimbra.account_api_url)
  
      # upload path 
      uri_path='/service/upload?fmt=raw'
    
      # open local file
      File.open(path) do |file|
        req = Net::HTTP::Post::Multipart.new(
          uri_path,
          file: UploadIO.new(file,'binary')
        )

        # Set auth cookie
        req['Cookie'] = "ZM_AUTH_TOKEN=#{Zimbra.account_auth_token}"
        req['Cookie'] += ";ZM_ADMIN_AUTH_TOKEN=#{Zimbra.auth_token}"
      
        http = Net::HTTP.new(base_uri.host, base_uri.port)
        http.use_ssl = true
    
        res = http.request(req)
        
        resp_code = res.code.to_i
        raise "Wrong response code '#{resp_code}'" unless resp_code == 200    
        
        match = /\d+\,'([^']*)','([^']*)'/.match(res.body)
        raise "Response body cannot be parsed '#{res.body}'" if match.nil?

        resp_code_inner = match[0].to_i
        raise "Wrong inner response code '#{resp_code_inner}'" unless resp_code_inner == 200    
        
        upload_id = match[2]
        raise "Wrong upload id '#{upload_id}'" if upload_id.length < 20 

  
        return upload_id
      end
    end

    class Builder
      class << self
        def create(message, upload_id, folder_path, flags, timestamp, tags)
          message.add 'm' do |message|
            message.set_attr 'noICal', 0
            message.set_attr 'l', folder_path
            message.set_attr 'aid', upload_id
            message.set_attr 'f', flags unless flags.nil?
            message.set_attr 'd', timestamp*1000 unless timestamp.nil?
            message.set_attr 'tn', tags unless tags.nil?
          end
        end
      end
    end
  end
end
