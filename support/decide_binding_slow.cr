require "bindgen/library"
require "yaml"

MIN_VERSION = ARGV[0]
RUN_MAKE    = ARGV[1]?

struct FindPathsDocument
  include YAML::Serializable
  property find_paths : Bindgen::FindPath::Configuration
end

# Load path finding configuration
config = Bindgen::ConfigReader.from_file(
  klass: FindPathsDocument,
  path: "#{__DIR__}/../config/find_paths.yml",
)

# Find the paths, populating `ENV`
finder = Bindgen::FindPath.new(Dir.current)
errors = finder.find_all!(config.find_paths)
errors.reject!(&.config.optional)
unless errors.empty? # Cheap error output.
  errors.each do |err|
    message = err.config.error_message
    STDERR.puts(message) if message
  end

  STDERR.puts "\nFailed to find one or more paths.  See above for details."
  exit 1
end

# `find_paths` sets QT_VERSION while searching for qmake.  If QMAKE was given
# instead, it doesn't search, so ask qmake.
qt_version = ENV["QT_VERSION"]? || `#{Process.quote(ENV["QMAKE"])} -query QT_VERSION`.strip
abort "#{ENV["QMAKE"]} is Qt #{qt_version}, not Qt5" unless qt_version.starts_with?("5.")

# Remove patch version: "5.9.2" -> "5.9"
detected_version = qt_version.split('.')[0..1].join('.')
vars = Bindgen::Variables.builtin

use_binding = "#{vars["os"]}-#{vars["libc"]}-#{vars["architecture"]}-qt#{detected_version}"

if RUN_MAKE
  Process.run(
    "make",
    [] of String,
    env: {"BINDING_PLATFORM" => use_binding},
    output: STDERR,
    error: STDERR,
    chdir: "#{__DIR__}/../ext",
  )
end

puts "#{detected_version} #{use_binding}"
