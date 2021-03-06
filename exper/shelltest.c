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

int
main(int argc, char* argv[]) {
  struct termios orig_termios, new_termios;
  struct winsize orig_winsize;
  int pty_master, pty_slave;
  char *pts_name;
  int   nread;
  char  buf[BUFFSIZE];
  pid_t pid;

  tcgetattr(STDIN_FILENO, &orig_termios);
  //ioctl(STDIN_FILENO, TIOCGWINSZ, (char *)&orig_winsize);

  pty_master = posix_openpt(O_RDWR);
  //grantpt(pty_master);
  unlockpt(pty_master);

  pts_name = ptsname(pty_master);

  // child
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
    //printf("master %d, slave %d\n", fcntl(pty_master, F_GETFL), fcntl(pty_slave, F_GETFL));
    execvp("sh", argv);
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

        //printf("nread:%d\r\n", nread);
        if (write(pty_master, buf, nread) != nread) break;
      }

      exit(0);
    } else {
      for ( ; ; ) {
        if ((nread = read(pty_master, buf, BUFFSIZE)) <= 0){
          //printf("master %d, slave %d\n", fcntl(pty_master, F_GETFL), fcntl(pty_slave, F_GETFL));
          //printf("break:%dn no:%d, %s\n", nread, errno, strerror(errno)); 
          break;
        }

        int wret = write(STDOUT_FILENO, buf, nread);
        int i;
        for(i = 0; i < nread; i++){
          if (buf[i] != '\n' && buf[i] != '\r')
            printf("%c", buf[i]);
          else
            printf("%s", buf[i] == '\n' ? "\\n" : "\\r");
        }
        //printf("wr:%d, rd:%d\n", wret, nread);
        if (wret != nread){ printf("break\n"); break;}
      }
    }
  }

  kill(pid, SIGTERM);
  tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig_termios);

  return 0;
}
