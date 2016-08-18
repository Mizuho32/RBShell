#!/usr/bin/env ruby
# coding:utf-8

require 'pty'
require './extool.so'

@pid = nil
@buf = ""
ExtTool.init($stdin.fileno)

@master = IO.open(pty_master_fn = ExtTool.posix_openpt, "r+")
ExtTool.grantpt(@master.fileno)
ExtTool.unlockpt(@master.fileno)

@pts_name = ExtTool.ptsname(@master.fileno)

if( fork == nil) then
  Process.setsid
  @slave = File.open((@pts_name), "r+")
  @master.close

  ExtTool.dup2(@slave.fileno, $stdin.fileno)
  ExtTool.dup2(@slave.fileno, $stdout.fileno)
  ExtTool.dup2(@slave.fileno, $stderr.fileno)
  @slave.close

  Process.exec(ARGV[0] || "bash") 
else
  system("stty raw -echo")
  
  if ( (@pid = fork) == nil) then
    loop do                     # for input into child shell
      @buf = $stdin.getc # in canonical, wait for ENTER key and displays key input
      next if (@buf == nil)
      break if (@buf.bytesize == 0) 
      break if(@master.write(@buf) != @buf.bytesize) 
    end
    exit(0)
  else
    loop {                     # for output outto parent shell
      begin
        @buf = @master.read_nonblock(512, "")
      rescue Errno::EIO => e
        break
      rescue IO::WaitReadable, IO::EAGAINWaitReadable
        IO.select([@master], [],[], )
        retry 
      end 
      break if (@buf.bytesize <= 0) 
      break if (($stdout.write(@buf)) != @buf.bytesize)
    }
  end

end

Process.kill("KILL", @pid)
system("stty -raw echo")

exit 0
