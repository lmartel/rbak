require 'fileutils'
require 'sequel'

module RBak
  module Helpers
    def base_path
      '.rbak'
    end

    def head_path
      path_to 'HEAD'
    end

    def head!
      File.read(head_path).to_i if File.exist?(head_path)
    end

    def write_head!(num)
      File.write(head_path, num)
    end

    def path_to(*args)
      "#{base_path}/#{args.join('/')}"
    end
  end

  module DB
    class << self
      include Helpers

      def init(filename)
        conn = Sequel.sqlite path_to(filename)
        conn.create_table? :backups do
          primary_key :number, default: 1
          Time :created, null: false
          String :message, null: true
          Integer :parent, null: true
        end
        RBak.const_set :Backup, conn[:backups]
      end
    end
  end

  class Main
    include Helpers

    def backup(m = nil)
      num = Backup.insert created: Time.now, message: m, parent: head!
      files = Dir.foreach('.').reject { |f| ['.', '..', '.git', base_path].include? f }

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
      DB.init 'backups.db'
    end

    def status
      puts "Backup #{head!} is currently checked out."
    end

    def log
      backups = Backup.order(:number).all.reverse
      groups = []
      until backups.empty?
        latest = backups.shift
        parent = latest[:parent]
        ancestor_numbers = []
        while parent
          ancestor_numbers << parent
          parent = Backup[number: parent][:parent]
        end

        ancestors, other = backups.partition { |bu| ancestor_numbers.include? bu[:number] }
        groups << [latest, *ancestors]
        backups = other
      end

      puts groups.map { |group|
        group.map { |b|
          "Backup #{b[:number]} <= #{b[:parent] or 'ROOT'} :: #{b[:message] or "<NO MESSAGE>"} (#{b[:created]})"
        }.join("\n")
      }.join("\n\n")
    end

    def diff(lhs, rhs)
      puts `diff #{lhs} #{rhs}`
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
      when 'status'
        status
      when 'log'
        log
      when 'diff'
        lhs = path_to ARGV[1]
        rhs = (ARGV[2] and path_to ARGV[2]) || '.'
        diff lhs, rhs
      else
        puts "Usage: rbak COMMAND"
        puts "Valid commands: 'backup', 'checkout', 'latest', 'status', 'log'"
      end
    end
  end
end

RBak::Main.new.main
