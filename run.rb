#!/usr/bin/env ruby
# coding:utf-8

$debug = if ARGV[0] then
          class <<(d=File.open(ARGV[0], "r+"))
            def p(line)
              self.puts line.inspect
              line
            end
          end
          d
        else
          $stdout
        end

require 'pathname'
$: << Pathname.new( (r=File.dirname(File.expand_path(__FILE__))) +"/lib").to_s << r + "/ext"
require 'lib.rb'

rsh = RBShell.new( (class Object; binding; end) )
rsh.start


