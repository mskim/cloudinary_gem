# Copyright Cloudinary
require 'digest/sha1'

class Cloudinary::Utils
  SHARED_CDN = "d3jpl91pxevbkh.cloudfront.net"
  
  # Warning: options are being destructively updated!
  def self.generate_transformation_string(options={})
    width = options[:width]
    height = options[:height]
    size = options.delete(:size)
    width, height = size.split("x") if size    
    options.delete(:width) if width && width < 1 
    options.delete(:height) if height && height < 1    
     
    crop = options.delete(:crop)
    width=height=nil if crop.nil?

    x = options.delete(:x)
    y = options.delete(:y)
    
    gravity = options.delete(:gravity)
    quality = options.delete(:quality)
    named_transformation = build_array(options.delete(:transformation)).join(".")
    prefix = options.delete(:prefix)

    params = {:w=>width, :h=>height, :t=>named_transformation, :c=>crop, :q=>quality, :g=>gravity, :p=>prefix, :x=>x, :y=>y}
    transformation = params.reject{|k,v| v.blank?}.map{|k,v| [k.to_s, v]}.sort_by(&:first).map{|k,v| "#{k}_#{v}"}.join(",")
    raw_transformation = options.delete(:raw_transformation)
    transformation = [transformation, raw_transformation].reject(&:blank?).join(",")
    transformation    
  end
  
  def self.api_sign_request(params_to_sign, api_secret)
    to_sign = params_to_sign.reject{|k,v| v.blank?}.map{|k,v| [k.to_s, v.is_a?(Array) ? v.join(",") : v]}.sort_by(&:first).map{|k,v| "#{k}=#{v}"}.join("&")
    Digest::SHA1.hexdigest("#{to_sign}#{api_secret}")
  end

  # Warning: options are being destructively updated!
  def self.cloudinary_url(source, options = {})
    transformation = self.generate_transformation_string(options)

    type = options.delete(:type) || :upload
    resource_type = options.delete(:resource_type) || "image"
    version = options.delete(:version)

    format = options.delete(:format)
    source = "#{source}.#{format}" if format && type != :fetch
    source = smart_escape(source) if [:fetch, :file].include?(type)
    
    # Configuration options
    # newsodrome.cloudinary.com, images.newsodrome.com, cloudinary.com/res/newsodrome, a9fj209daf.cloudfront.net
    cloud_name = options.delete(:cloud_name) || Cloudinary.config.cloud_name || raise("Must supply cloud_name in tag or in configuration")
    
    if cloud_name.start_with?("/")
      prefix = "/res" + cloud_name
    else
      secure = options.delete(:secure) || Cloudinary.config.secure
      private_cdn = options.delete(:private_cdn) || Cloudinary.config.private_cdn    
      secure_distribution = options.delete(:secure_distribution) || Cloudinary.config.secure_distribution
      if secure && secure_distribution.nil?
        if private_cdn
          raise "secure_distribution not defined"
        else
          secure_distribution = SHARED_CDN 
        end
      end
      
      if secure
        prefix = "https://#{secure_distribution}"
      else
        prefix = "http://#{private_cdn ? "#{cloud_name}-" : ""}res.cloudinary.com"
      end    
      prefix += "/#{cloud_name}" if !private_cdn
    end
    
    source = prefix + "/" + [resource_type, 
     type, transformation, version ? "v#{version}" : nil,
     source].reject(&:blank?).join("/").gsub("//", "/")
  end
  
  # Based on CGI::unescape. In addition does not escape / : 
  def self.smart_escape(string)
    string.gsub(/([^ a-zA-Z0-9_.-\/:]+)/) do
      '%' + $1.unpack('H2' * $1.bytesize).join('%').upcase
    end.tr(' ', '+')
  end
  
  def self.random_public_id
    (defined?(ActiveSupport::SecureRandom) ? ActiveSupport::SecureRandom : SecureRandom).base64(16).downcase.gsub(/[^a-z0-9]/, "")    
  end
  
  @@json_decode = false
  def self.json_decode(str)
    if !@@json_decode
      @@json_decode = true
      begin
        require 'json'
      rescue LoadError
        begin
          require 'active_support/json'
        rescue LoadError
          raise "Please add the json gem or active_support to your Gemfile"            
        end
      end
    end
    defined?(JSON) ? JSON.parse(str) : ActiveSupport::JSON.decode(str)
  end

  def self.build_array(array)
    case array
      when Array then array
      when nil then []
      else [array]
    end
  end
end
