#!/usr/bin/env ruby
# coding:utf-8

require 'pty'
require 'extool'
require 'open3'

require 'rubyorshell'

$debug = $debug || $stdout

module Terminal
  extend self

  #%w[for while if end case when .. { } class module].any?{|n| line.include? n}
  Rules = { 
            /(\d+)/ => "\e[34m\\1\e[0m",    # Num
            /(:[a-zA-Z_][a-zA-Z_\d]*)/ => "\e[33m\\1\e[0m",   # symbol
            /(true|false|nil)/ => "\e[96m\\1\e[0m",           # bool, nil
            /(for|while|if|end|case|when|class|module)/ => "\e[32m\\1\e[0m",  # keyword
            /((?:'(?:[^']|\\')*')|(?:"(?:[^"]|\\')*"))/ => "\e[31m\\1\e[0m",  # string
          }
  def coloring(line)
    Rules.inject(line){|o,(k,v)|
      o.gsub(k,v)
    }
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

class Object
  def method_missing(name, *arg, &block)
    if %i[to_hash to_ary to_str to_int].include? name || !RubyOrShell.possibly_system_command?(name.to_s) then 
      return super
    end
    #p name, self
    #gets
    $debug.puts "missing: #{name.to_s} of #{self}".inspect
    begin 
      super
    rescue Exception => e1
      $stderr.print e1.message.gsub("\n", "\r\n") + "\r\n"
      begin
        #out = Open3.capture3(name.to_s)
        out = RBShell.master.print(name.to_s)
        #out = spawn(name.to_s)
        #out = nil
        #puts out[0]
        return `echo $?`#out[2].exitstatus
      rescue Exception => e
        $stderr.puts e.message
        exit(1)
      end
    end
  end
end

class RBShell
  include RubyOrShell

  class << RBShell
    attr_accessor :master
  end

  def initialize(binding)
    @pid = nil
    @buf = ""
    ExtTool.init($stdin.fileno)

    RBShell.master = @master = IO.open(pty_master_fn = ExtTool.posix_openpt, "r+")
    ExtTool.grantpt(@master.fileno)
    ExtTool.unlockpt(@master.fileno)

    @pts_name = ExtTool.ptsname(@master.fileno)
    @line = ""
    @ruby = false
    @code = ""
    @output = true
    @binding = binding
    @indent = 0
  end

  def evaluate(code)
    begin
      print "\n\r"
      out = eval(@code, @binding)
      print "\r=>#{out.inspect.gsub("\n", "\r\n")}\r\n"
    rescue Exception => e
      print "\r"
      puts e.message
    end
    @code = ""
    @ruby = false
  end

  # string -> bool
  # returns if complete ruby expression?
  def input_line(line)      
    @code += @line + "\n"

    if start?(line) then
      @indent += 1
      if _end?(line)
        @indent -= 1
      end
    elsif _end?(line)
      @indent -= 1
    end

    if @indent == 0 then
      evaluate(@code)
      return true
    else
      return false
    end
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

      Process.exec(ARGV[1] || "bash") 
    }
  end

  def sendinput
    system("stty raw -echo")
    begin
      @pid = Thread.fork{
        loop do                     # for input into child shell
          c = $stdin.getc # in canonical, wait for ENTER key and displays key input
          #p c
          next if (c == nil)
          break if (c.bytesize == 0) 

          #p c
          if c.ord == 127 then
            @line.chop!
            #$stdout.write(0x08.chr)
          elsif c == "\f" then
            #ignore
          elsif c == "\r" then
            $debug.p @line
            unless $debug.p(t = possibly_system_command?(@line.strip)) then 
              $stdout.sync = true

              @output = false
              @master.write(0x15.chr)
              sleep 0.001   # fixme
              @output = true
              $stdout.write "\b\e[K"*@line.size
              $stdout.write("\n\r> " + Terminal.coloring(@line))
              # possiby ruby exp
              input_line(@line.strip)
            end
            @line = ""

          elsif [0x03,0x04].include? c.ord then # ^C ^D
            @master.write c
              
            @line = ""
          #elsif [0x10].include? c.ord
          else
            @line += c
          end

          break if(@master.write(c) != c.bytesize) 
        end
        exit(0)
      }
      #@pid.join
    rescue
      p $!
      puts "\r"
      @pid.kill
      system "stty -raw echo"
      exit 1
    end
  end

  def start
    launch
    sendinput
    
    #ExtTool.receive_output(@master.fileno, $stdout.fileno)
#=begin
      loop {         # for output outto parent shell
        begin
          @buf = @master.read_nonblock(512, "")
        rescue Errno::EIO => e
          break
        rescue IO::WaitReadable, IO::EAGAINWaitReadable
          IO.select([@master], [],[], )
          $debug.puts "EAGAIN"
          retry 
        end 
        break if (@buf.bytesize <= 0) 
        break if (($stdout.write(@buf)) != @buf.bytesize) if @output
        $debug.puts @buf.inspect
        #$stdout.print ":#{@buf}"
        #p @buf
      }
#=end

    if @pid.instance_of? Fixnum then
      Process.kill("KILL", @pid)
    else
      @pid.kill
    end
    system("stty -raw echo")
  end


  #eval "ls"
  #eval "puts [*0..10].select(&:odd?)"

end


#rbsh = RBShell.new
#rbsh.start()
