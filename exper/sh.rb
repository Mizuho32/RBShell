#!/usr/bin/env ruby
# coding:utf-8

require 'pty'
require './ext/extool.so'
require 'open3'
require 'curses'

module RubyOrShell
  extend self #Debug

  def possibly_system_command?(line)
    line = line.strip

    return line =~ /(?:^\.?\/)|(?:-\w+)/ || 
           %w[ls dir cd cp mv rm].any?{|n| line.include? n}
  end

  def surely_ruby_expression!(line)
    line = line.strip
    return line =~ /^(?:\w|@|\$)+\s*=\s*.+/ ||
            %w[for while if end case when .. { } class module].any?{|n| line.include? n}
  end
end

module Kernel
  alias_method :_puts_, :puts
  def puts(*arg)
    _puts_(*(arg.map{|n| 
      if n.instance_of? String then
        n.gsub("\n", "\r\n")
      else
        "#{n}\r"
      end
    }))
  end
end

class RBShell
  include RubyOrShell

  class << self
    def method_missing(name, *arg, &block)
      begin
        out = Open3.capture3(name.to_s)
      rescue Exception => e
        $stderr.puts e.message
        exit(1)
      end
      p out
    end
  end

  def initialize
    @pid = nil 
    @buf = ""
    ExtTool.init($stdin.fileno)

    @master = IO.open(pty_master_fn = ExtTool.posix_openpt, "r+")
    ExtTool.grantpt(@master.fileno)
    ExtTool.unlockpt(@master.fileno)

    @pts_name = ExtTool.ptsname(@master.fileno)
    @line = ""
    @ruby = false
    @code = ""
    @output = true
  end

  def launch
    fork{
      Process.setsid
      @slave = File.open((@pts_name), "r+")
      @master.close

      ExtTool.dup2(@slave.fileno, $stdin.fileno)
      ExtTool.dup2(@slave.fileno, $stdout.fileno)
      ExtTool.dup2(@slave.fileno, $stderr.fileno)
      @slave.close

      Process.exec(ARGV[0] || "bash") 
    }
  end

  def sendinput
    system("stty raw")
    @pid = Thread.fork{
      loop do                     # for input into child shell
        c = $stdin.getc # in canonical, wait for ENTER key and displays key input
        next if (c == nil)
        break if (c.bytesize == 0) 
        #$stdout.send :p,c; 
        #p c
        if c.ord == 127 then
          @line.chop!
          #$stdout.write(0x08.chr)
        elsif c == "\f" then
          #ignore
        elsif c == "\r" then
          @output = false
          if (surely_ruby_expression!(@line) || @ruby) then
            @ruby = true unless @ruby

            $stdout.sync = true
            #@master.sync = true
            #p @line
            #@line.size.times{|n| $stdout.write(0x08.chr)}#0x15.chr)
            #@master.flush
            #@master.write(0x15.chr)
            #IO.select([$stdin], [$stdout],[], )
            #p @line
            #sleep 0.5
            #$stdout.print "#{@line}"

          
            @code += @line + "\n"
            if %w[end }].any?{|n| @line.include? n} then
              #p @code
              begin
                print "\n\r"
                out = instance_eval(@code)
                print "\r=>#{out.inspect.gsub("\n", "\r\n")}\n"
              rescue Exception => e
                print "\r"
                puts e.message
              end

              @code = ""
              @ruby = false
              #@master.write(0x15.chr)
            else
              #$stdout.print "#{@line}"
              #@line.size.times{|n| @master.write(0x08.chr)}#0x15.chr)
            end
          else
            #@line.size.times{|n| @master.write(0x08.chr)}
            #$stdout.write "\r"
            #$stdout.write 0x15.chr
            #sleep 1
            @master.write(@line) 
            #sleep 0.5
            @output = true
            #sleep 0.5
            @master.write("\r\n")
            #@output = false
            @line = ""
          end
            
          @line = ""
        #elsif c == "\n" then
          #$stdout.write 0x15.chr
          #sleep 1
          #@master.write(@line + c) 
          #@line = ""
        else
          #$stdout.write c
          @line += c
        end

        #break if(@master.write(c) != c.bytesize) 
      end
      exit(0)
    }
  end

  def start
    launch
    sendinput
    #ExtTool.receive_output(@master.fileno, $stdout.fileno)
#=begin
      loop {         # for output outto parent shell
        begin
          @buf = @master.read_nonblock(512, "")#.gsub("\r", "")
        rescue Errno::EIO => e
          break
        rescue IO::WaitReadable, IO::EAGAINWaitReadable
          IO.select([@master], [],[], )
          retry 
        end 
        break if (@buf.bytesize <= 0) 
        break if (($stdout.write(@buf)) != @buf.bytesize)
        #p @buf
        #$stdout.print "#{@buf}" if @output
        #p @buf
      }
#=end

    #Process.kill("KILL", @pid)
    system("stty -raw echo")
  end


  #eval "ls"
  #eval "puts [*0..10].select(&:odd?)"

end


rbsh = RBShell.new
rbsh.start()
