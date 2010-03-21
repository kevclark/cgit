CGIT_VERSION = v0.8.3.1
CGIT_SCRIPT_NAME = cgit.cgi
CGIT_SCRIPT_PATH = /var/www/htdocs/cgit
CGIT_DATA_PATH = $(CGIT_SCRIPT_PATH)
CGIT_CONFIG = /etc/cgitrc
CACHE_ROOT = /var/cache/cgit
SHA1_HEADER = <openssl/sha.h>
GIT_VER = 1.7.0
GIT_URL = http://www.kernel.org/pub/software/scm/git/git-$(GIT_VER).tar.bz2
INSTALL = install
EXTLIBS = 
OBJECTS =
CFLAGS = 
COMPAT_CFLAGS =
COMPAT_OBJS =

# Define NO_STRCASESTR if you don't have strcasestr.
#
# Define NO_OPENSSL to disable linking with OpenSSL and use bundled SHA1
# implementation (slower).
#
# Define NEEDS_LIBICONV if linking with libc is not enough (eg. Darwin).
#

#-include config.mak

#
# Platform specific tweaks
#

uname_S := $(shell sh -c 'uname -s 2>/dev/null || echo not')
uname_O := $(shell sh -c 'uname -o 2>/dev/null || echo not')
uname_R := $(shell sh -c 'uname -r 2>/dev/null || echo not')

ifeq ($(uname_O),Cygwin)
	NO_STRCASESTR = YesPlease
	NEEDS_LIBICONV = YesPlease
endif

ifneq (,$(findstring MINGW,$(uname_S)))
	pathsep = ;
	__MINGW__ = YesPlease
	NO_PREAD = YesPlease
	NEEDS_CRYPTO_WITH_SSL = YesPlease
	NO_LIBGEN_H = YesPlease
	NO_SYMLINK_HEAD = YesPlease
	NO_SETENV = YesPlease
	NO_UNSETENV = YesPlease
	NO_STRCASESTR = YesPlease
	NO_STRLCPY = YesPlease
	NO_MEMMEM = YesPlease
	NEEDS_LIBICONV = YesPlease
	OLD_ICONV = YesPlease
	NO_C99_FORMAT = YesPlease
	NO_STRTOUMAX = YesPlease
	NO_MKDTEMP = YesPlease
	NO_MKSTEMPS = YesPlease
	SNPRINTF_RETURNS_BOGUS = YesPlease
	NO_SVN_TESTS = YesPlease
	NO_PERL_MAKEMAKER = YesPlease
	RUNTIME_PREFIX = YesPlease
	NO_POSIX_ONLY_PROGRAMS = YesPlease
	NO_ST_BLOCKS_IN_STRUCT_STAT = YesPlease
	NO_NSEC = YesPlease
	USE_WIN32_MMAP = YesPlease
	USE_NED_ALLOCATOR = YesPlease
	UNRELIABLE_FSTAT = UnfortunatelyYes
	OBJECT_CREATION_USES_RENAMES = UnfortunatelyNeedsTo
	NO_REGEX = YesPlease
	NO_PYTHON = YesPlease
	BLK_SHA1 = YesPlease
	COMPAT_CFLAGS += -D__USE_MINGW_ACCESS -DNOGDI -DNO_MMAP -DNO_REGEX -DNO_SETENV -DNO_STRLCPY -D__MINGW__ -Igit/compat -Igit/compat/fnmatch -Igit/compat/win32 -Igit/compat/regex
	COMPAT_CFLAGS += -DSTRIP_EXTENSION=\".exe\"
	# We have GCC, so let's make use of those nice options
#	COMPAT_CFLAGS += -Werror -Wno-pointer-to-int-cast \
#	        -Wold-style-definition -Wdeclaration-after-statement
	COMPAT_CFLAGS += -Werror -Wno-pointer-to-int-cast
	COMPAT_OBJS += git/compat/mingw.o git/compat/fnmatch/fnmatch.o git/compat/winansi.o \
		git/compat/win32/pthread.o
	PTHREAD_LIBS =
	CFLAGS += $(COMPAT_CFLAGS)
	OBJECTS += $(COMPAT_OBJS)
	X = .exe
endif

#
# Let the user override the above settings.
#
-include cgit.conf

#
# Define a way to invoke make in subdirs quietly, shamelessly ripped
# from git.git
#
QUIET_SUBDIR0  = +$(MAKE) -C # space to separate -C and subdir
QUIET_SUBDIR1  =

ifneq ($(findstring $(MAKEFLAGS),w),w)
PRINT_DIR = --no-print-directory
else # "make -w"
NO_SUBDIR = :
endif

ifndef V
	QUIET_CC       = @echo '   ' CC $@;
	QUIET_MM       = @echo '   ' MM $@;
	QUIET_SUBDIR0  = +@subdir=
	QUIET_SUBDIR1  = ;$(NO_SUBDIR) echo '   ' SUBDIR $$subdir; \
			 $(MAKE) $(PRINT_DIR) -C $$subdir
endif

#
# Define a pattern rule for automatic dependency building
#
%.d: %.c
	$(QUIET_MM)$(CC) $(CFLAGS) -MM $< | sed -e 's/\($*\)\.o:/\1.o $@:/g' >$@

#
# Define a pattern rule for silent object building
#
%.o: %.c
	$(QUIET_CC)$(CC) -o $*.o -c $(CFLAGS) $<


EXTLIBS += git/libgit.a git/xdiff/lib.a -lz

ifdef __MINGW__
	EXTLIBS += -lws2_32 -lwsock32
endif

OBJECTS += cache.o
OBJECTS += cgit.o
OBJECTS += cmd.o
OBJECTS += configfile.o
OBJECTS += html.o
OBJECTS += parsing.o
OBJECTS += scan-tree.o
OBJECTS += shared.o
OBJECTS += ui-atom.o
OBJECTS += ui-blob.o
OBJECTS += ui-clone.o
OBJECTS += ui-commit.o
OBJECTS += ui-diff.o
OBJECTS += ui-log.o
OBJECTS += ui-patch.o
OBJECTS += ui-plain.o
OBJECTS += ui-refs.o
OBJECTS += ui-repolist.o
OBJECTS += ui-shared.o
OBJECTS += ui-snapshot.o
OBJECTS += ui-ssdiff.o
OBJECTS += ui-stats.o
OBJECTS += ui-summary.o
OBJECTS += ui-tag.o
OBJECTS += ui-tree.o

ifdef NEEDS_LIBICONV
	EXTLIBS += -liconv
endif


.PHONY: all libgit test install uninstall clean force-version get-git \
	doc man-doc html-doc clean-doc

all: cgit

VERSION: force-version
	@./gen-version.sh "$(CGIT_VERSION)"
-include VERSION


CFLAGS += -g -Wall -Igit
CFLAGS += -DSHA1_HEADER='$(SHA1_HEADER)'
CFLAGS += -DCGIT_VERSION='"$(CGIT_VERSION)"'
CFLAGS += -DCGIT_CONFIG='"$(CGIT_CONFIG)"'
CFLAGS += -DCGIT_SCRIPT_NAME='"$(CGIT_SCRIPT_NAME)"'
CFLAGS += -DCGIT_CACHE_ROOT='"$(CACHE_ROOT)"'

ifdef NO_ICONV
	CFLAGS += -DNO_ICONV
endif
ifdef NO_STRCASESTR
	CFLAGS += -DNO_STRCASESTR
endif
ifdef NO_OPENSSL
	CFLAGS += -DNO_OPENSSL
	GIT_OPTIONS += NO_OPENSSL=1
else
	EXTLIBS += -lcrypto
endif

cgit: $(OBJECTS) libgit
	$(QUIET_CC)$(CC) $(CFLAGS) $(LDFLAGS) -o cgit $(OBJECTS) $(EXTLIBS)

cgit.o: VERSION

-include $(OBJECTS:.o=.d)

libgit:
	$(QUIET_SUBDIR0)git $(QUIET_SUBDIR1) NO_CURL=1 $(GIT_OPTIONS) libgit.a
	$(QUIET_SUBDIR0)git $(QUIET_SUBDIR1) NO_CURL=1 $(GIT_OPTIONS) xdiff/lib.a

test: all
	$(QUIET_SUBDIR0)tests $(QUIET_SUBDIR1) all

install: all
	$(INSTALL) -m 0755 -d $(DESTDIR)$(CGIT_SCRIPT_PATH)
	$(INSTALL) -m 0755 cgit $(DESTDIR)$(CGIT_SCRIPT_PATH)/$(CGIT_SCRIPT_NAME)
	$(INSTALL) -m 0755 -d $(DESTDIR)$(CGIT_DATA_PATH)
	$(INSTALL) -m 0644 cgit.css $(DESTDIR)$(CGIT_DATA_PATH)/cgit.css
	$(INSTALL) -m 0644 cgit.png $(DESTDIR)$(CGIT_DATA_PATH)/cgit.png

uninstall:
	rm -f $(CGIT_SCRIPT_PATH)/$(CGIT_SCRIPT_NAME)
	rm -f $(CGIT_DATA_PATH)/cgit.css
	rm -f $(CGIT_DATA_PATH)/cgit.png

doc: man-doc html-doc pdf-doc

man-doc: cgitrc.5.txt
	a2x -f manpage cgitrc.5.txt

html-doc: cgitrc.5.txt
	a2x -f xhtml --stylesheet=cgit-doc.css cgitrc.5.txt

pdf-doc: cgitrc.5.txt
	a2x -f pdf cgitrc.5.txt

clean: clean-doc
	rm -f cgit VERSION *.o *.d

clean-doc:
	rm -f cgitrc.5 cgitrc.5.html cgitrc.5.pdf cgitrc.5.xml cgitrc.5.fo

get-git:
	curl $(GIT_URL) | tar -xj && rm -rf git && mv git-$(GIT_VER) git
