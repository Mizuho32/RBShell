require 'test/unit'
require 'pp'
require 'pathname'
require 'custom'

$: << Pathname.new(File.dirname(File.expand_path(__FILE__))).parent.to_s + "/lib"

require 'rubyorshell'

class Test_IN < Test::Unit::TestCase

	def setup
	end

  must "ruby expression" do
    assert_equal(RubyOrShell.surely_ruby_expression!(" @hi = `./a.out`") >=0 , true)
  end 

	must "command?" do
    assert_equal(true, RubyOrShell.possibly_system_command?("./a.out") >= 0)
    assert_equal(true, RubyOrShell.possibly_system_command?("/bin/bash") >= 0)
    assert_equal(true, RubyOrShell.possibly_system_command?("ls -la") >= 0)
  end

	must "system command" do
    assert_equal(true, RubyOrShell.possibly_system_command?("ls"))
    assert_equal(true, RubyOrShell.possibly_system_command?("dir"))
    assert_equal(true, RubyOrShell.possibly_system_command?("cd"))
    assert_equal(true, RubyOrShell.possibly_system_command?("cp"))
    assert_equal(true, RubyOrShell.possibly_system_command?("mv"))
    assert_equal(true, RubyOrShell.possibly_system_command?("rm"))
	end 

  must "not system command" do
    assert_equal(false, RubyOrShell.possibly_system_command?("true"))
    assert_equal(false, RubyOrShell.possibly_system_command?("false"))
    assert_equal(false, RubyOrShell.possibly_system_command?("nil"))
  end

end
