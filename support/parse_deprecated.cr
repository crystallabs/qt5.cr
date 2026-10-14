require "yaml"

outfile = "config/deprecated.yml"
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

File.write(outfile, results.to_yaml)

# Arguments, like `--system`, are passed on to generate_bindings.cr.
output = `crystal run support/generate_bindings.cr -- #{Process.quote(ARGV)} 2>&1`
unless $?.success?
  STDERR.puts output.lines.last(30).join
  abort "Generating the bindings failed, see above"
end
output.each_line do |line|
  # GCC reports the full declaration, e.g.:
  #   warning: 'void QSpinBox::valueChanged(const QString&)' is deprecated
  next unless line =~ /warning: [‘'][^‘’']*?\b(Q\w+)::(\w+)\(.*[’'] is deprecated/
  klass, method = $1, $2
  results[klass] = {"ignore_methods" => Array(String).new} unless results[klass]?
  results[klass]["ignore_methods"] << method
end

results.each do |_, v|
  v["ignore_methods"].uniq!
end

pp results

File.write(outfile, results.to_yaml)
