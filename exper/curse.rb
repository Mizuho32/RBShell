#!/usr/bin/env ruby

require "curses"

include Curses

init_screen
begin
  s = "Hello World!"
  setpos(lines / 2, cols / 2 - (s.length / 2))
  addstr(s + "\n 12345\b\b")
  refresh
  getch
ensure
  close_screen
end
