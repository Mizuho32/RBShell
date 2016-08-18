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
#include <conio.h>

#define BUFFSIZE 512

void sysread(void);
void kbh(void);

int
main(int argc, char* argv[]) {
  struct termios orig_termios, new_termios;
  struct winsize orig_winsize;
  int pty_master, pty_slave;
  char *pts_name;
  int   nread;
  char  buf[BUFFSIZE];
  pid_t pid;

  kbh();

  return 0;
}

void kbh(void){
  for(;;){
    if(kbhit()){
      printf("%c", getch());
    }
  }
}

void sysread(void){
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
