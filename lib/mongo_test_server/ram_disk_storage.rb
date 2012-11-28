# coding: UTF-8

module MongoTestServer

  class RamDiskStorage

    class << self
      def supported?
        `which hdiutil`!=''
      end
    end

    def initialize(name)
      @name = "#{name}-mongo-ram-disk"
      @path = "/Volumes/#{@name}"
    end

    def create
      @ram_disk_device ||= lambda {
        device = `hdiutil attach -nomount ram://1000000`.chomp
        `diskutil erasevolume HFS+ #{@name} #{device}`
        device
        }.call
      path
    end

    def path
      @path
    end

    def delete
      `umount #{path} 2> /dev/null`
      `hdiutil detach #{@ram_disk_device} 2> /dev/null`
    end

  end

end