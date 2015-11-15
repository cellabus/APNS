module APNS
  require "openssl"

  class Notification
    attr_accessor :device_token, :alert, :badge, :sound, :other, :priority
    attr_accessor :message_identifier, :expiration_date
    attr_accessor :content_available

    def initialize(device_token, message)
      self.device_token = device_token
      if message.is_a?(Hash)
        self.alert = message[:alert]
        self.badge = message[:badge]
        self.sound = message[:sound]
        self.other = message[:other]
        self.message_identifier = message[:message_identifier]
        self.content_available = !message[:content_available].nil?
        self.expiration_date = message[:expiration_date]
        self.priority = if content_available
                          message[:priority] || 5
                        else
                          message[:priority] || 10
        end
      elsif message.is_a?(String)
        self.alert = message
      else
        fail "Notification needs to have either a hash or string"
      end

      self.message_identifier ||= OpenSSL::Random.random_bytes(4)
    end

    def packaged_notification
      pt = packaged_token
      pm = packaged_message
      pi = self.message_identifier
      pe = (expiration_date || 0).to_i
      pr = (priority || 10).to_i

      # Each item consist of
      # 1. unsigned char [1 byte] is the item (type) number according to Apple's docs
      # 2. short [big endian, 2 byte] is the size of this item
      # 3. item data, depending on the type fixed or variable length
      data = ""
      data << [1, pt.bytesize, pt].pack("CnA*")
      data << [2, pm.bytesize, pm].pack("CnA*")
      data << [3, pi.bytesize, pi].pack("CnA*")
      data << [4, 4, pe].pack("CnN")
      data << [5, 1, pr].pack("CnC")

      # Return the full notification frame:
      # Each notification frame consists of
      # 1. (e.g. protocol version) 2 (unsigned char [1 byte])
      # 2. size of the full frame (unsigend int [4 byte], big endian)
      # 3. the data assembled above
      ([2, data.bytesize].pack("CN") + data)
    end

    def packaged_token
      [device_token.gsub(/[\s|<|>]/, "")].pack("H*")
    end

    def packaged_message
      aps = { "aps" => {} }
      aps["aps"]["alert"] = alert if alert
      aps["aps"]["badge"] = badge if badge
      aps["aps"]["sound"] = sound if sound
      aps["aps"]["content-available"] = 1 if content_available

      aps.merge!(other) if other
      aps.to_json
    end
  end
end
