#!/usr/bin/env ruby
# coding:utf-8

require 'pty'
require './ext/extool.so'

@master, @slave = PTY.open
@pid = nil
@buf = ""

if( fork == nil) then
  Process.setsid
  @master.close

  p ExtTool
  ExtTool.dup2(@slave.fileno, $stdin.fileno)
  ExtTool.dup2(@slave.fileno, $stdout.fileno)
  ExtTool.dup2(@slave.fileno, $stderr.fileno)
=begin
  $stdin.reopen(@slave.dup)
  $stdout.reopen(@slave.dup)
  $stderr.reopen(@slave.dup)
=end
  @slave.close

  #$stdin.close; $stdout.close; $stderr.close
  #$stdin.close_on_exec = $stdout.close_on_exec = $stderr.close_on_exec = true
  Process.exec(ARGV[0] || "bash") 
else
#  system("stty raw -echo")
  
  if ( (@pid = fork) == nil) then
    loop do                     # for input into child shell
      @buf = $stdin.getc # in canonical, wait for ENTER key and displays key input
      #p @buf,@master.write(@buf)
      break if (@buf.bytesize == 0) 
      break if(@master.write(@buf) != @buf.bytesize) 
    end
    #puts "child exit"
    exit(0)
  else
    #sleep 1000
#=begin
    loop do                     # for output outto parent shell
      #puts "write:#{$stdout.write(@master.getc.bytesize)}"
      #@buf = @master.getc
      begin
        @master.read_nonblock(512, @buf)
      rescue Errno::EIO => e
        puts "IOError: #{e.message}"
        break
      rescue IO::WaitReadable, IO::EAGAINWaitReadable
        IO.select([@master], [],[], )
        puts "HI"
        retry 
      end 
      #p @buf, @buf.bytesize
      #break if ((@buf).bytesize <= 0) 
      #break if (($stdout.write(@buf)) != @buf.bytesize)
      $stdout.print(":#{@buf}")
      @buf = ""
    end
#=end
  end

end

#Process.wait(@pid)
Process.kill("KILL", @pid)
#system("stty -raw echo")

exit 0
