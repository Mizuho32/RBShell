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
  Rules = { # fixme "JI:JI1+2+3#{1+2}"
            #Num
            /(\d+)/ => "\e[94m\\1\e[0m",
            # symbol
            /:(['"]?)((?:(?:[a-zA-Z_][a-zA-Z_\d]*)|(?:(?:[^']|\\')*|(?:[^"]|\\')*))\??)\1/ => "\e[33m:\e[93m\\1\e[33m\\2\e[93\\1\e[0m",   
            # bool, nil
            /(true|false|nil)/ => "\e[96m\\1\e[0m",           
            # keyword
            /(for|while|if|end|case|when|class|module|then)/ => "\e[32m\\1\e[0m",  
            # string
            /(['"])((?:[^']|\\')*|(?:[^"]|\\')*)\1/ => "\e[91m\\1\e[31m\\2\e[0m\e[91m\\1\e[0m",  
          }
  def coloring(line)
    Rules.inject(line){|o,(k,v)|
      #$debug.p 
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

  TAB=2

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
    #$debug.puts "run: #{code.inspect}"
    begin
      print "\n\r"
      out = eval(@code, @binding)
      print "\r=>#{Terminal.coloring(out.inspect.gsub("\n", "\r\n"))}\r\n"
    rescue Exception => e
      print "\r"
      puts e.message
    end
    @code = ""
    @ruby = false
  end

  # string -> bool
  # returns if "end" given?
  def input_line(line)      
    @code += @line + "\n"

    if start?(line) then
      @indent += 1
      if _end?(line)
        @indent -= 1
      end
    elsif _end?(line)
      @indent -= 1
      return 1
    end

    return 0

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

          if @indent > 0 then
            if c == "\r"
              #$debug.p @indent
              $stdout.write "\b\e[K"*(@line.size)
              $stdout.write "\b\e[K"*TAB*input_line(@line.strip)
              $stdout.write(Terminal.coloring(@line))
              #$debug.p @indent
              if @indent > 0 then
                $stdout.write("\n\r> #{' '*TAB*@indent}")
              else
                evaluate(@code)
              end
              @line = ""
            elsif c == "\u007F"  # Delete
              if @line != ""
                $stdout.write "\b\e[K"
                @line.chop!
              end
            else
              $stdout.print c
              @line += c
            end

            next if @indent > 0
          end

          if c.ord == 127 then
            @line.chop!
            #$stdout.write(0x08.chr)
          elsif c == "\f" then
            #ignore
          elsif c == "\r" then
            $debug.p @line
            unless possibly_system_command?(@line.strip) then 
              #$stdout.sync = true

              @output = false
              @master.write(0x15.chr)
              sleep 0.001   # fixme
              @output = true
              $stdout.write "\b\e[K"*@line.size
              $stdout.write("\n\r> #{' '*TAB*@indent}" + Terminal.coloring(@line))
              # possiby ruby exp
              input_line(@line.strip) 
              evaluate(@code) if @indent == 0

              $stdout.write("\n\r> #{' '*TAB*@indent}") if @indent > 0
            end
            @line = ""

          elsif [0x03,0x04].include? c.ord then # ^C ^D
            @master.write c
              
            @line = ""
          #elsif [0x10].include? c.ord
          else
            @line += c
          end

          break if(@master.write(c) != c.bytesize) if @indent == 0
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
