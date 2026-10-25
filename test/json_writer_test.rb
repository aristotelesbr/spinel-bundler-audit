require "spinel_bundler_audit"
require_relative "fixtures/json_sample"

puts json_sample(SpinelBundlerAudit::JsonWriter.new(false))
puts json_sample(SpinelBundlerAudit::JsonWriter.new(true))
