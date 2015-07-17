require 'fileutils'
require 'sequel'

module RBak
  module BackupModel
    def new(*args)
      initialize(*args)
    end

    def initialize

    end
  end

  module Helpers
    def base_path
      '.rbak'
    end

    def head_path
      path_to 'HEAD'
    end

    def head
      File.read(head_path).to_i
    end

    def write_head!(num)
      File.write(head_path, num)
    end

    def path_to(*args)
      "#{base_path}/#{args.join('/')}"
    end
  end

  class DB
    include Helpers

    def initialize(filename)
      conn = Sequel.sqlite path_to(filename)
      conn.create_table? :backups do
        primary_key :number, default: 1
        Time :created, null: false
        String :message, null: true
      end
      RBak.const_set :Backup, conn[:backups]
      # Backup.class.instance_eval { include BackupModel }
    end
  end

  class Main
    include Helpers

    def backup(m = nil)
      num = Backup.insert created: Time.now, message: m
      files = Dir.foreach('.').reject { |f| ['.', '..', base_path].include? f }

      FileUtils.mkdir_p path_to(num)
      files.each do |f|
        FileUtils.cp_r f, path_to(num)
      end
      num
    end

    def checkout(num)
      FileUtils.cp_r path_to(num, '.'), '.'
    end

    def setup
      FileUtils.mkdir_p base_path
      @DB = DB.new 'backups.db'
    end

    def main
      setup
      case ARGV.first
      when 'backup'
        msg = ARGV[ARGV.index('-m') + 1] if ARGV.include? '-m'
        num = backup msg
        write_head! num
      when 'checkout'
        num = ARGV[1].to_i
        checkout num
        write_head! num
      when 'latest'
        num = Backup.order(:number).last[:number]
        checkout num
        write_head! num
      else
        puts "Usage: rbak COMMAND"
        puts "Valid commands: 'backup', 'checkout', 'latest', 'log'"
      end
    end
  end

end

RBak::Main.new.main
