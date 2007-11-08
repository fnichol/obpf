# $Id$

# Copyright (c) 2007, Fletcher Nichol
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

.include "bsd.obpf.common.mk"

#
# Path to common commands
#
AWK = /usr/bin/awk
BASENAME = /usr/bin/basename
CHMOD = /bin/chmod
CHROOT = /usr/sbin/chroot
CP = /bin/cp
DIRNAME = /usr/bin/dirname
ECHO = /bin/echo
EGREP = /usr/bin/egrep
FIND = /usr/bin/find
FTP = /usr/bin/ftp
GREP = /usr/bin/grep
HEAD = /usr/bin/head
LS = /bin/ls
MD5 = /bin/md5
MKDIR = /bin/mkdir
MOUNT_MFS = /sbin/mount_mfs
MV = /bin/mv
PATCH = /usr/bin/patch
SED = /usr/bin/sed
TAR = /bin/tar
TOUCH = /usr/bin/touch
UMOUNT = /sbin/umount
UNAME = /usr/bin/uname
XARGS = /usr/bin/xargs

#
# Global path locations
#
DISTDIR ?= ${.CURDIR}/distfiles
_DISTDIR := ${DISTDIR}
FULLDISTDIR ?= ${_DISTDIR}

DISTNAME ?= openbsd-${OSREV}
WRKDIR ?= ${.CURDIR}/w-${DISTNAME}
WRKDIST ?= ${WRKDIR}/${DISTNAME}


_WRKDIR_COOKIE = ${WRKDIR}/.extract_started
_EXTRACT_COOKIE = ${WRKDIR}/.extract_done
_BUILD_COOKIE = ${WRKDIR}/.build_done

_MAKE_COOKIE = ${TOUCH}

.include <bsd.own.mk>

#
# A few aliases for *-install targets
#
INSTALL_PROGRAM = \
	${INSTALL} ${INSTALL_COPY} ${INSTALL_STRIP} \
		-o ${BINOWN} -g ${BINGRP} -m ${BINMODE}
INSTALL_SCRIPT = \
	${INSTALL} ${INSTALL_COPY} -o ${BINOWN} -g ${BINGRP} -m ${BINMODE}
INSTALL_DATA = \
	${INSTALL} ${INSTALL_COPY} -o ${SHAREOWN} -g ${SHAREGRP} -m ${SHAREMODE}
INSTALL_MAN = \
	${INSTALL} ${INSTALL_COPY} -o ${MANOWN} -g ${MANGRP} -m ${MANMODE}

INSTALL_PROGRAM_DIR = \
	${INSTALL} -d -o ${BINOWN} -g ${BINGRP} -m ${DIRMODE}
INSTALL_SCRIPT_DIR = \
	${INSTALL_PROGRAM_DIR}
INSTALL_DATA_DIR = \
	${INSTALL} -d -o ${SHAREOWN} -g ${SHAREGRP} -m ${DIRMODE}
INSTALL_MAN_DIR = \
	${INSTALL} -d -o ${MANOWN} -g ${MANGRP} -m ${DIRMODE}


#
# Common commands and operations
#

# Used to print all the '===>' style prompts -- override this to turn them off
ECHO_MSG ?= ${ECHO}

# Used to fetch any remote file
FTP_KEEPALIVE ?= 0
FETCH_CMD ?= ${FTP} -V -m -k ${FTP_KEEPALIVE}

CHECKSUM_FILE ?= ${FULLDISTDIR}/${OSREV}/${MACHINE}/MD5

CHROOT_SHELL ?= /bin/ksh -li

.if defined(verbose-show)
.MAIN: verbose-show
.elif defined(show)
.MAIN: show
.elif defined(clean)
.MAIN: clean
.elif defined(_internal-clean)
clean = ${_internal-clean}
.MAIN: _internal-clean
.else
.MAIN: all
.endif

# need to go through an extra var because clean is set in stone,
# on the cmdline.
_clean = ${clean}
.if empty(_clean) || ${_clean:L} == "depends"
_clean += work
.endif
.if ${_clean:L:Mwork}
_clean += fake
.endif
.if ${_clean:L:Mforce}
_clean += -f
.endif
# check that clean is clean
_okay_words = depends work fake -f flavors dist install sub packages package \
	readmes bulk force plist
.for _w in ${_clean:L}
.  if !${_okay_words:M${_w}}
ERRORS += "Fatal: unknown clean command: ${_w}"
.  endif
.endfor

# Default OpenBSD site
_MASTER_SITE_OPENBSD ?= \
	ftp://ftp.openbsd.org/pub/OpenBSD/ \
	ftp://ftp.usa.openbsd.org/pub/OpenBSD/

# Empty declarations to avoid "variable XXX is recursive" errors
MASTER_SITES ?=
# Unless an override is declared, check MASTER_SITES, then the fallback sites
.if !defined(MASTER_SITE_OVERRIDE)
MASTER_SITES := ${MASTER_SITES} ${_MASTER_SITE_OPENBSD}
.else
MASTER_SITES := ${MASTER_SITE_OVERRIDE} ${MASTER_SITES}
.endif


#
# _SITE_SELECTOR chooses the value of sites based on select.
#
_SITE_SELECTOR = case $$select in

.for _I in 0 1 2 3 4 5 6 7 8 9
.  if defined(MASTER_SITES${_I})
.    if !defined(MASTER_SITE_OVERRIDE)
MASTER_SITES${_I} := ${MASTER_SITES${_I}} ${_MASTER_SITE_OPENBSD}
.    else
MASTER_SITES${_I} := ${MASTER_SITE_OVERRIDE} ${MASTER_SITES${_I}}
.    endif
_SITE_SELECTOR += *:${_I}) sites="${MASTER_SITES${_I}}";;
.  else
_SITE_SELECTOR += *:${_I}) echo >&2 "Error: MASTER_SITES${_I} not defined";;
.  endif
.endfor

_SITE_SELECTOR += *) sites="${MASTER_SITES}";; esac


# Default OpenBSD packages tar blobs to fetch
_DISTFILES_OS ?= \
	${OSREV}/${MACHINE}/MD5 \
	${OSREV}/${MACHINE}/base${OSrev}.tgz \
	${OSREV}/${MACHINE}/etc${OSrev}.tgz \
	${OSREV}/${MACHINE}/comp${OSrev}.tgz \
	${OSREV}/${MACHINE}/man${OSrev}.tgz \
	${OSREV}/${MACHINE}/misc${OSrev}.tgz \
	${OSREV}/${MACHINE}/xbase${OSrev}.tgz \

# Default OpenBSD source tar blobs to fetch
_DISTFILES_SRC ?= \
	${OSREV}/src.tar.gz \
	${OSREV}/sys.tar.gz \
	${OSREV}/xenocara.tar.gz \

# Any additional kernel configurations to be installed into the source tree
# These must be available from either an FTP or HTTP server
KERNELCONFS ?=

DISTFILES ?= ${_DISTFILES_OS} ${_DISTFILES_SRC} ${KERNELCONFS}

_EVERYTHING = ${DISTFILES}
_DISTFILES = ${DISTFILES:C/:[0-9]$//}
ALLFILES = ${_DISTFILES}




_internal-fetch:
.  if target(pre-fetch)
	@cd ${.CURDIR} && exec ${MAKE} pre-fetch
.  endif
.  if !empty(ALLFILES)
	@cd ${.CURDIR} && exec ${MAKE} ${ALLFILES:S@^@${FULLDISTDIR}/@}
.  endif
.  if target(post-fetch)
	@cd ${.CURDIR} && exec ${MAKE} post-fetch
.  endif


_internal-checksum: _internal-fetch
	@cd ${CHECKSUM_FILE:H}; OK=true; \
	for file in ${_DISTFILES_OS}; do \
		filename=`basename $$file`; \
		if [ "$$filename" == "${CHECKSUM_FILE:T}" ]; then continue; fi; \
		if ! grep "^MD5 ($$filename) = " ${CHECKSUM_FILE} > /dev/null; then \
			${ECHO_MSG} ">> No checksum recorded for $$file."; \
			OK=false; \
		else \
			grep "^MD5 ($$filename) = " ${CHECKSUM_FILE} | md5 -c; \
			if [ "$$?" -ne "0" ]; then \
				echo ">> Checksum mismatch for $$file."; \
				OK=false; \
			fi; \
		fi; \
	done; \
	if ! $$OK; then \
		${ECHO_MSG} "Make sure the Makefile and checksum file (${CHECKSUM_FILE})"; \
		${ECHO_MSG} "are up to date."; \
		exit 1; \
	fi

# The cookie's recipe hold the real rule for each of these targets
_internal-extract: ${_EXTRACT_COOKIE}
_internal-build: ${_BUILD_COOKIE}


# The real targets. Note that some parts always get run, some parts can be
# disabled, and there are hooks to override behavior.

${_WRKDIR_COOKIE}:
	@rm -rf ${WRKDIR}
	@mkdir -p ${WRKDIR}
	@${_MAKE_COOKIE} $@

${_EXTRACT_COOKIE}: ${_WRKDIR_COOKIE}
	@cd ${.CURDIR} && exec ${MAKE} _internal-checksum
	@${ECHO_MSG} "===>  Extracting for ${DISTNAME}"
.if target(pre-extract)
	@cd ${.CURDIR} && exec ${MAKE} pre-extract
.endif
	@cd ${.CURDIR} && exec ${MAKE} do-extract
.if target(post-extract)
	@cd ${.CURDIR} && exec ${MAKE} post-extract
.endif
	@${_MAKE_COOKIE} $@


.if !target(do-extract)
do-extract:
	@mkdir -p ${WRKDIST}
	@for file in ${_DISTFILES_OS:C/:[0-9]$//}; do \
		if [ "`basename $$file`" == "${CHECKSUM_FILE:T}" ]; then continue; fi; \
		${ECHO_MSG} -n "===> Extracting `basename $$file` ... "; \
		${SUDO} tar xpfz ${DISTDIR}/$$file -C ${WRKDIST}; \
		${ECHO_MSG} "Done."; \
	done
	@for file in ${_DISTFILES_SRC:C/:[0-9]$//}; do \
		${ECHO_MSG} -n "===> Extracting `basename $$file` ... "; \
		${SUDO} tar xpfz ${DISTDIR}/$$file -C ${WRKDIST}/usr/src; \
		${ECHO_MSG} "Done."; \
	done
	@for file in ${KERNELCONFS:C/:[0-9]$//}; do \
		${ECHO_MSG} -n "===> Extracting Kernel config `basename $$file` ... "; \
		${SUDO} ${INSTALL} -m 0644 -o 0 -g 0 ${DISTDIR}/$$file \
			${WRKDIST}/usr/src/sys/arch/${MACHINE}/conf; \
		${ECHO_MSG} "Done."; \
	done
.endif


${_BUILD_COOKIE}: ${_EXTRACT_COOKIE}
	@${ECHO_MSG} "===>  Building for ${DISTNAME}"
.if target(pre-build)
	@cd ${.CURDIR} && exec ${MAKE} pre-build
.endif
	@cd ${.CURDIR} && exec ${MAKE} do-build
.if target(post-build)
	@cd ${.CURDIR} && exec ${MAKE} post-build
.endif
	@${_MAKE_COOKIE} $@


.if !target(do-build)
do-build:
	@${ECHO_MSG} -n "===> Preparing /dev ... "
	@${SUDO} ${MV} ${WRKDIST}/dev ${WRKDIST}/dev.orig
	@${SUDO} ${INSTALL} -d -m 0755 -o 0 -g 0 ${WRKDIST}/dev
	@${ECHO_MSG} "Done."
	@${ECHO_MSG} -n "===> Installing chroot Makefile ... "
	@${SUDO} ${INSTALL_DATA} ${.CURDIR}/bsd.obpf.chroot.mk ${WRKDIST}
	@${SUDO} ${INSTALL_DATA} ${.CURDIR}/bsd.obpf.common.mk ${WRKDIST}
	@${ECHO_MSG} "Done."
.endif

_internal-chroot: ${_BUILD_COOKIE}
	@${ECHO_MSG} "===>  chrooting into ${DISTNAME}"
	@cd ${.CURDIR} && exec ${MAKE} pre-chroot
	@cd ${.CURDIR} && exec ${MAKE} do-chroot
	@cd ${.CURDIR} && exec ${MAKE} post-chroot


.if !target(pre-chroot)
pre-chroot:
	@${ECHO_MSG} "===>  Creating standard devices for chroot environment"
	@${SUDO} ${MOUNT_MFS} -o nosuid -s 8192 swap ${WRKDIST}/dev
	@${SUDO} ${CP} -p ${WRKDIST}/dev.orig/MAKEDEV ${WRKDIST}/dev/
	@cd ${WRKDIST}/dev/ && ${SUDO} ./MAKEDEV std
	@${ECHO_MSG} "===>  Creating copies of system files in chroot environment"
	@${SUDO} ${CP} -p /etc/resolv.conf ${WRKDIST}/etc/
	@${SUDO} ${CP} -p /etc/hosts ${WRKDIST}/etc/
.endif


.if !target(do-chroot)
do-chroot:
	@cd ${.CURDIR} && ${SUDO} exec ${CHROOT} ${WRKDIST} ${CHROOT_SHELL}
.endif


.if !target(post-chroot)
post-chroot:
	@${ECHO_MSG} -n "===>  Removing chroot environment standard devices ... "
	@${SUDO} ${UMOUNT} -f ${WRKDIST}/dev
	@${ECHO_MSG} "Done."
.endif


# Seperate target for each file fetch will retrieve
.for _F in ${ALLFILES:S@^@${FULLDISTDIR}/@}
${_F}:
	@mkdir -p ${_F:H}; \
	cd ${_F:H}; \
	select=${_EVERYTHING:M*${_F:S@^${FULLDISTDIR}/@@}\:[0-9]}; \
	f=${_F:S@^${FULLDISTDIR}/@@}; \
	${ECHO_MSG} ">> $$f doesn't seem to exist on this system."; \
	${_SITE_SELECTOR}; \
	for site in $$sites; do \
		${ECHO_MSG} ">> Fetch $${site}$$f."; \
		if ${FETCH_CMD} $${site}$$f; then \
			exit 0; \
		fi; \
	done; exit 1
.endfor


# Top-level targets redirect to the real _internal-target
.for _t in fetch checksum extract build chroot clean
${_t}: _internal-${_t}
.endfor


#####################################################
# Cleaning up
#####################################################
_internal-clean:
	@${ECHO_MSG} "===>  Cleaning"
.if ${_clean:L:Mwork}
	@if [ -L ${WRKDIR} ]; then rm -rf `readlink ${WRKDIR}`; fi
	@rm -rf ${WRKDIR}
.endif
.if ${_clean:L:Mdist}
	@${ECHO_MSG} "===>  Dist cleaning"
	@if cd ${DISTDIR} 2>/dev/null; then \
		rm -f ${ALLFILES}; \
	fi
	@rm -rf ${FULLDISTDIR}
.endif


#####################################################
# Convenience targets
#####################################################

distclean:
	@cd ${.CURDIR} && exec ${MAKE} clean=dist

peek-ftp:
	@mkdir -p ${FULLDISTDIR}; cd ${FULLDISTDIR}; echo "cd ${FULLDISTDIR}"; \
	for i in ${MASTER_SITES:Mftp*}; do \
		echo "Connecting to $$i"; ${FETCH_CMD} $$i ; break; \
	done

