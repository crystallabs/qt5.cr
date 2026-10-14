require "yaml"

outfile = "config/deprecated.yml"
results = {
  "QTableWidgetItem" => {
    "ignore_methods" => ["operator<"],
  },
  # "QUrl" => {
  #   "ignore_methods" => [
  #     "toCFURL",
  #     "fromCFURL",

  #   ],
  # }
}

File.write(outfile, results.to_yaml)

output = `crystal run support/generate_bindings.cr 2>&1`
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
