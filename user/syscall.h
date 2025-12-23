#ifndef _USER_SYSCALL_H_
#define _USER_SYSCALL_H_

#include "syscall_numbers.h"

// User-visible syscall wrappers (matched to kernel task requirements).
int fork(void);
void exit(int status) __attribute__((noreturn));
int wait(int* status);
int kill(int pid);
int getpid(void);
int open(const char* path, int flags);
int close(int fd);
int read(int fd, void* buf, int len);
int write(int fd, const void* buf, int len);
void* sbrk(int increment);
int yield(void);

#endif // _USER_SYSCALL_H_
