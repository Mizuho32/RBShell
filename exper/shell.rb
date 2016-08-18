#!/usr/bin/env ruby
# coding:utf-8

require 'socket'
require 'open3'
require 'pty'

#require 'systemu'

=begin
IO.popen 'sh', 'r+' do |io|
  io.puts 'echo how now brown cow | tr a-z A-Z'
  #io.puts 'ls' + "\t"
  result = io.gets
  p [:result, result.size, result]
end
=end

#out, err, stat = Open3.capture3("", stdin_data:"ls\t")
#p out,err,stat

=begin
Open3.popen3("ls\t") do |stdin, stdout, stderr|
  stdin.puts "shell *\n"
  
  stdout.each_line{|line| puts line}
  stdin.close
=end


# p [*( systemu("ls shell\t"))]


=begin
PTY.spawn("l\t") do |out_, in_, pid|
  in_.close
begin
  while l = out_.gets
    puts "out: #{l}"
  end
rescue Errno::EIO
ensure
  Process.wait pid
end

end
=end

master, slave = PTY.open
system("stty raw -echo", :in=>$stdin)
#system("stty raw", :in=>master)
read, write = IO.pipe

pid = fork{
  #$stdout.reopen  File.open("/tmp/child", "w")
  #$stdout.puts "child"
  $stdout.reopen slave
#  $stdin.reopen slave
  $stderr.reopen slave
  slave.close
  exec "/bin/bash"
}

@parentout = $stdout
@line = ""
pid2 = fork{
  pid3 = fork{
    loop do
      $stdout.write(master.read(1))
    end
  }
  loop do
=begin
    c=$stdin.getc#.chomp
    if c.ord == 127 then
      @line.chop!
    else
      @line += c
    end
    puts c.ord
    if(c.ord == 127)
      @line.chop!
      #puts @line
    else
      @line += c
    end
    #puts c.ord
    if(c == "\n" || c == "\t" || c.ord == 0x0D)
      #puts "input: #{c}: #{c.ord}"
      #system("stty -raw", :in=>$stdin)
      #$stdout.puts("#{@line + "\t\t"}".inspect)
      #master.write(@line + "\t\t")
      #$stdout.puts("line #{@line}")
      master.puts(@line)
      master.flush
      @line = ""
    elsif( @line.include? "exit" )
      system("stty -raw", :in=>$stdin)
      master.puts(@line)
      @line = ""
    else
      #$stdout.puts(@line + ":line")
    end
=end
    c=$stdin.getc
    
    if c.ord == 127 then
      @line.chop!
    elsif c.ord == 10 then
      @line = ""
    else
      @line += c
    end
    master.write(c)
    #@parentout.puts @line
    if @line.include? "exit" then
      system("stty -raw", :in=>$stdin)
      break
    end
  end
  Process.kill("KILL", pid3)
  exit(0)
}

=begin
pid3 = fork{
loop do
  #puts "main loop: #{@line}\r\n"
  line = master.read(1)
  $stdout.write(line)
  if @line.include? "exit" then
    puts "EXIT"
    break
  end
end
}
=end

Process.wait(pid2)
#Process.kill("KILL", pid3)

#$stdout.puts "parent"
