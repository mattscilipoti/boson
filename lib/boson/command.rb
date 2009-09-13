require 'shellwords'
module Boson
  class Command
    def self.create(name, library)
      new (library.commands_hash[name] || {}).merge({:name=>name, :lib=>library.name})
    end

    def self.create_aliases(commands, lib_module)
      aliases_hash = {}
      select_commands = Boson.commands.select {|e| commands.include?(e.name)}
      select_commands.each do |e|
        if e.alias
          aliases_hash[lib_module.to_s] ||= {}
          aliases_hash[lib_module.to_s][e.name] = e.alias
        end
      end
      generate_aliases(aliases_hash)
    end

    def self.generate_aliases(aliases_hash)
      Alias.manager.create_aliases(:instance_method, aliases_hash)
    end

    attr_accessor :name, :lib, :alias, :description, :options, :args
    def initialize(hash)
      @name = hash[:name] or raise ArgumentError
      @lib = hash[:lib] or raise ArgumentError
      @alias = hash[:alias] if hash[:alias]
      @description = hash[:description] if hash[:description]
      @options = hash[:options] if hash[:options]
      @args = hash[:args] if hash[:args]
    end

    def library
      @library ||= Boson.library(@lib)
    end

    def args
      @args ||= begin
        if library && File.exists?(library.library_file || '')
          file_string = Boson::FileLibrary.read_library_file(library.library_file)
          Inspector.arguments_from_file(file_string, @name)
        end
      end
    end

    def option_parser
      @option_parser ||= (@options ? Options.new(@options) : nil)
    end

    def option_help
      @options ? option_parser.to_s : ''
    end

    def has_splat_args?
      @args && @args.any? {|e| e[0][/^\*/] }
    end

    def usage
      return '' if options.nil? && args.nil?
      usage_args = args && @options ? args[0..-2] : args
      str = args ? usage_args.map {|e| "[#{e.join('=')}]"}.join(' ') : '[*unknown]'
      str + option_help
    end

    def create_option_command_block
      command = self
      options = @options.delete(:options) || {}
      default_lambda = lambda {|*args|
        if args.size == 1 && args[0].is_a?(String)
          args = Shellwords.shellwords(args.join(" "))
          parsed_options = command.option_parser.parse(args)
          args = command.option_parser.non_opts.delete_if {|e| bool = e[/^-/]; $stderr.puts "Invalid option #{e}" if bool; bool}
        # last string argument interpreted as args + options
        elsif args.size > 1 && args[-1].is_a?(String)
          parsed_options = command.option_parser.parse(args.pop.split(/\s+/))
          args += command.option_parser.non_opts.delete_if {|e| bool = e[/^-/]; $stderr.puts "Invalid option #{e}" if bool; bool}
        # default options
        elsif command.args && args.size == command.args.size - 1
          parsed_options = command.option_parser.parse([])
        end
        if parsed_options
          parsed_options = Util.symbolize_keys(parsed_options)
          args << parsed_options
          if command.args && args.size < command.args.size && !command.has_splat_args?
            raise ArgumentError, "wrong number of arguments (#{args.size} for #{command.args.size})"
          end
        end
        p args
        super(*args)
      }
    end
  end
end