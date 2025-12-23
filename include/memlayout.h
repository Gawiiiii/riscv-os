// include/memlayout.h
#ifndef MEMLAYOUT_H
#define MEMLAYOUT_H

#ifndef KERNBASE
#define KERNBASE 0x80000000UL
#endif

#ifndef PHYSTOP
#define PHYSTOP 0x88000000UL
#endif

#ifndef RAM_START
#define RAM_START KERNBASE
#endif

#ifndef RAM_END
#define RAM_END PHYSTOP
#endif

#endif // MEMLAYOUT_H
