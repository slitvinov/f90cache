CC      ?= cc
CFLAGS  ?= -O2 -Wall
PREFIX  ?= /usr/local

bindir = $(PREFIX)/bin
mandir = $(PREFIX)/share/man

OBJS = f90cache.o mdfour.o hash.o execute.o util.o args.o stats.o cleanup.o snprintf.o

.SUFFIXES: .c .o

all: f90cache

f90cache: $(OBJS)
	$(CC) $(CFLAGS) -o f90cache $(OBJS)

.c.o:
	$(CC) -I. $(CFLAGS) -c $<

install: f90cache
	install -d $(DESTDIR)$(bindir)
	install -m 755 f90cache $(DESTDIR)$(bindir)/
	install -d $(DESTDIR)$(mandir)/man1
	install -m 644 f90cache.1 $(DESTDIR)$(mandir)/man1/

clean:
	rm -f $(OBJS) f90cache

$(OBJS): f90cache.h mdfour.h config.h
