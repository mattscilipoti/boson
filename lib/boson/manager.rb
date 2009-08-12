module Boson
  module Manager
    extend self
    def init(options={})
      $:.unshift File.dirname(__FILE__) unless $:.include? File.expand_path(File.dirname(__FILE__))
      Boson.main_object.extend Libraries
      create_initial_libraries(options)
      load_default_libraries(options)
      @initialized = true
    end

    def load_default_libraries(options)
      defaults = [Boson::Libraries::Core, Boson::Libraries::ObjectCommands]
      defaults << IRB::ExtendCommandBundle if Object.const_defined?(:IRB) && IRB.const_defined?(:ExtendCommandBundle)
      defaults += Boson.config[:defaults] if Boson.config[:defaults]
      Library.load(defaults)
    end

    def create_initial_libraries(options)
      detected_libraries = Dir[File.join(Boson.dir, 'libraries', '**/*.rb')].map {|e| e.gsub(/.*libraries\//,'').gsub('.rb','') }
      libs = (detected_libraries + Boson.config[:libraries].keys).uniq
      Library.create(libs, options)
    end

    def activate(options={})
      init(options) unless @initialized
      libraries = options[:libraries] || []
      Library.load(libraries, options)
    end
  end
end