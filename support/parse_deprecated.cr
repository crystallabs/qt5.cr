require "yaml"

# Regenerates `config/deprecated.yml`: Generates the binding with every method,
# and then ignores each method the C++ compiler warns to be deprecated.
#
# Arguments, like `--system`, are passed on to generate_bindings.cr.

OUTFILE = "config/deprecated.yml"
EXT_DIR = "ext" # The compiler runs in here, file names are relative to it.

# A deprecated method, as found in a compiler warning.
record Deprecation, klass : String, method : String

# GCC reports the full declaration, e.g.:
#   qt_binding_linux-gnu-x86_64-qt5.15.cpp:123:45: warning:
#   'static QString QSpinBox::trUtf8(const char*, const char*, int)' is deprecated
module GccWarning
  PATTERN = /warning: [‘'][^‘’']*?\b(Q\w+)::(\w+)\(.*[’'] is deprecated/

  def self.parse(line) : Deprecation?
    Deprecation.new($1, $2) if line =~ PATTERN
  end
end

# Clang only reports the name, e.g.:
#   qt_binding_darwin-unknown-aarch64-qt5.15.cpp:123:45: warning:
#   'trUtf8' is deprecated
# The class is the one of the enclosing `bg_<Class>_<method>_<args>` wrapper
# function in the generated C++ file.
module ClangWarning
  PATTERN = /^([^:\s]+\.cpp):(\d+):\d+: warning: [‘'](\w+)[’'] is deprecated/

  # Start of a wrapper function, e.g.:
  #   extern "C" QString bg_QSpinBox_trUtf8_const_char_X_const_char_X_int(...) {
  # Nested classes are mangled like `QFoo__Bar`, just use the inner one.
  WRAPPER = /^extern "C" .*?\bbg_(?:[A-Za-z0-9]+__)*([A-Za-z0-9]+)_/

  @@sources = Hash(String, Array(String)).new

  def self.parse(line) : Deprecation?
    return unless line =~ PATTERN
    file, line_number, method = $1, $2.to_i, $3

    klass = enclosing_class(File.expand_path(file, EXT_DIR), line_number)
    Deprecation.new(klass, method) if klass
  end

  # Finds the class of the wrapper function around *line_number* of *path*.
  private def self.enclosing_class(path, line_number) : String?
    lines = @@sources[path] ||= File.read_lines(path)
    (line_number - 1).clamp(..lines.size - 1).downto(0) do |index|
      line = lines[index]
      return $1 if line =~ WRAPPER
      return if line.starts_with?('}') # Past the end of a previous definition.
    end
  end
end

def parse_warning(line) : Deprecation?
  GccWarning.parse(line) || ClangWarning.parse(line)
end

# Any deprecation warning, to detect those no format understood.
DEPRECATION_WARNING = /warning: .* is deprecated/

# Methods ignored for reasons other than deprecation.
results = {
  "QTableWidgetItem" => {
    "ignore_methods" => ["operator<"],
  },
  "QPolygon" => { # Variadic
    "ignore_methods" => ["putPoints", "setPoints"],
  },
  # "QUrl" => {
  #   "ignore_methods" => [
  #     "toCFURL",
  #     "fromCFURL",

  #   ],
  # }
}

# Restore the previous file if anything below fails, instead of leaving only
# the stub behind.
previous = File.read(OUTFILE) if File.exists?(OUTFILE)
written = false
at_exit do
  next if written
  if previous
    File.write(OUTFILE, previous)
  else
    File.delete?(OUTFILE)
  end
end

File.write(OUTFILE, results.to_yaml)

output = `crystal run support/generate_bindings.cr -- #{Process.quote(ARGV)} 2>&1`
unless $?.success?
  STDERR.puts output.lines(chomp: false).last(30).join
  abort "Generating the bindings failed, see above"
end

unmatched = [] of String
output.each_line do |line|
  next unless line =~ DEPRECATION_WARNING

  unless deprecation = parse_warning(line)
    unmatched << line
    next
  end

  entry = results[deprecation.klass] ||= {"ignore_methods" => Array(String).new}
  entry["ignore_methods"] << deprecation.method
end

unless unmatched.empty?
  STDERR.puts unmatched.uniq.join('\n')
  abort "Couldn't find the class of the deprecated methods above"
end

results.each do |_, v|
  v["ignore_methods"].uniq!
end

pp results

File.write(OUTFILE, results.to_yaml)
written = true
puts "Wrote #{OUTFILE}.  The binding was generated with the deprecated methods,"
puts "regenerate it before use."
