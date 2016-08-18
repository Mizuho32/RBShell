#!/usr/bin/ruby

system("stty raw", in:$stdin)
c = $stdin.getc
system("stty -raw", in:$stdin)
puts "\ninput is #{c}: #{c.ord}"

