require 'rake/testtask'

task :default => [:test]

Rake::TestTask.new do |test|
	test.libs << "test"
	test.test_files = Dir[ "tests/test_*.rb" ]
	test.verbose = true
end
