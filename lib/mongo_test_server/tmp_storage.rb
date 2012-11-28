# coding: UTF-8

module MongoTestServer

  class TmpStorage

    require 'tmpdir'
    require 'fileutils'

    def initialize(name)
      @name = "#{name}-mongo-tmp"
      @tmp_dir = "#{Dir.tmpdir}/#{@name}"
    end

    def create
      FileUtils.mkdir_p @tmp_dir
      path
    end

    def path
      @tmp_dir
    end

    def delete
      FileUtils.rm_rf @tmp_dir
    end

  end

end