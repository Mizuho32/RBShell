module RubyOrShell
  extend self #Debug

  # must be stripped
  def possibly_system_command?(line)
    return line =~ /(?:^\.?\/)|(?:-\w+)/ || 
           %w[ls dir cd cp mv rm rmdir ln exit echo].any?{|n| line =~ /^#{n}/}
  end

  # must be stripped
  def surely_ruby_expression!(line)
    line = line.strip
    return line =~ /^(?:\w|@|\$)+\s*=\s*.+/ ||
            %w[for while if end case when .. { } class module].any?{|n| line.include? n}
  end
  
  # must be stripped
  def start?(line)
    return %w[for while if case { class module def].any?{|n| line.include? n}
  end
  
  # must be stripped
  def _end?(line)
    return line =~ /end|\}/
  end
end
