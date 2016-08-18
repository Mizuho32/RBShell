#define _XOPEN_SOURCE
#include <unistd.h>
#include <stdlib.h>
#include <signal.h>
#include <fcntl.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <fcntl.h>

#define BUFFSIZE 512

#include "ruby.h"

VALUE wrap_dup2(VALUE self, VALUE old_, VALUE new_){
  int old, new;

  old = FIX2INT(old_);
  new = FIX2INT(new_);

  dup2(old, new); 
  return Qnil;
}
//VALUE wrap_start(VALUE self);

VALUE wrap_init(VALUE self, VALUE fileno){
  struct termios orig_termios;

  int fn = FIX2INT(fileno);
  tcgetattr(fn, &orig_termios);
  ioctl(fn, TIOCSWINSZ, (char *)&orig_termios);
  
  return Qnil;
}

VALUE wrap_posix_openpt(VALUE self){
  return INT2NUM(posix_openpt(O_RDWR));
}

VALUE wrap_grantpt(VALUE self, VALUE fileno){
  grantpt(FIX2INT(fileno));
  return Qnil;
}

VALUE wrap_unlockpt(VALUE self, VALUE fileno){
  unlockpt(FIX2INT(fileno));
  return Qnil;
}

VALUE wrap_ptsname(VALUE self, VALUE fileno){
  char *pts_name = ptsname(FIX2INT(fileno));
  return rb_str_new2(pts_name);
}

VALUE wrap_open(VALUE self, VALUE name){
  return INT2NUM(open(StringValuePtr(name), O_RDWR));
}

VALUE wrap_receive_output(VALUE self, VALUE master_, VALUE stdout_){
  int master = FIX2INT(master_), out = FIX2INT(stdout_);
  char buf[512];
  int nread;

  for (;;){
    if ((nread = read(master, buf, 512)) <= 0) break;

    if (write(out, buf, nread) != nread) break;
  }

  return Qnil;
}


void Init_extool(){
  VALUE module;

  module = rb_define_module("ExtTool");
  rb_define_module_function(module, "dup2", wrap_dup2, 2);
  rb_define_module_function(module, "init", wrap_init, 1);
  rb_define_module_function(module, "posix_openpt", wrap_posix_openpt, 0);
  rb_define_module_function(module, "grantpt", wrap_grantpt, 1);
  rb_define_module_function(module, "unlockpt", wrap_unlockpt, 1);
  rb_define_module_function(module, "ptsname", wrap_ptsname, 1);
  rb_define_module_function(module, "open", wrap_open, 1);
  rb_define_module_function(module, "receive_output", wrap_receive_output, 2);

  //rb_define_module_function(module, "start", wrap_start, 0);
}

/*
VALUE wrap_start(VALUE self){
  struct termios orig_termios, new_termios;
  struct winsize orig_winsize;
  int pty_master, pty_slave;
  char *pts_name;
  int   nread;
  char  buf[BUFFSIZE];
  pid_t pid;

  tcgetattr(STDIN_FILENO, &orig_termios);
  ioctl(STDIN_FILENO, TIOCGWINSZ, (char *)&orig_winsize);

  pty_master = posix_openpt(O_RDWR);
  grantpt(pty_master);
  unlockpt(pty_master);

  pts_name = ptsname(pty_master);

  if (fork() == 0) {
    setsid();

    pty_slave = open(pts_name, O_RDWR);
    close(pty_master);

    tcsetattr(pty_slave, TCSANOW, &orig_termios);
    ioctl(pty_slave, TIOCSWINSZ, &orig_winsize);

    dup2(pty_slave, STDIN_FILENO);
    dup2(pty_slave, STDOUT_FILENO);
    dup2(pty_slave, STDERR_FILENO);
    close(pty_slave);
    execvp("bash", NULL);
  } else {
    new_termios = orig_termios;

    new_termios.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
    new_termios.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
    new_termios.c_cflag &= ~(CSIZE | PARENB);
    new_termios.c_cflag |= CS8;
    new_termios.c_oflag &= ~(OPOST);
    new_termios.c_cc[VMIN]  = 1;
    new_termios.c_cc[VTIME] = 0;

    tcsetattr(STDIN_FILENO, TCSAFLUSH, &new_termios);

    if ((pid = fork()) == 0) {
      for ( ; ; ) {
        nread = read(STDIN_FILENO, buf, BUFFSIZE);

        if (nread < 0 || nread == 0) break;

        if (write(pty_master, buf, nread) != nread) break;
      }

      exit(0);
    } else {
      for ( ; ; ) {
        if ((nread = read(pty_master, buf, BUFFSIZE)) <= 0) break;

        if (write(STDOUT_FILENO, buf, nread) != nread) break;
      }
    }
  }

  kill(pid, SIGTERM);
  tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig_termios);

  return 0;
}
*/
