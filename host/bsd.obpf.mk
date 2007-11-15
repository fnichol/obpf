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

#
# Path to common commands
#
AWK = /usr/bin/awk
BASENAME = /usr/bin/basename
CAT = /bin/cat
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
KSH = /bin/ksh
LS = /bin/ls
MD5 = /bin/md5
MKDIR = /bin/mkdir
MOUNT_MFS = /sbin/mount_mfs
MV = /bin/mv
PATCH_CMD = /usr/bin/patch
RM = /bin/rm
SED = /usr/bin/sed
SORT = /usr/bin/sort
SUDO = /usr/bin/sudo
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
PATCHDIST ?= ${WRKDIR}/patches-${OSREV}
FAKEDIR ?= ${WRKDIR}/fake-${OSREV}
PACKAGE_REPOSITORY ?= ${.CURDIR}/packages


_WRKDIR_COOKIE = ${WRKDIR}/.extract_started
_EXTRACT_COOKIE = ${WRKDIR}/.extract_done
_CONFIGURE_COOKIE = ${WRKDIR}/.configure_done
_PRE_PATCH_COOKIE = ${WRKDIR}/.${PATCH}-pre_patch_done
_PATCH_COOKIE = ${WRKDIR}/.${PATCH}-patch_done
_BUILD_COOKIE = ${WRKDIR}/.${PATCH}-build_done
_PLIST_COOKIE = ${WRKDIR}/.${PATCH}.plist
_FAKE_COOKIE = ${WRKDIR}/.${PATCH}-fake_done

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
FETCH_CMD ?= ${FTP} -V -m

CHECKSUM_FILE ?= ${FULLDISTDIR}/${OSREV}/${MACHINE}/MD5

CHROOT_SHELL ?= ${KSH} -li

.if defined(P)
PATCH = ${P}
.endif

.if defined(PATCH) && exists(${PATCHDIST}/${OSREV}/common) && exists(${PATCHDIST}/${OSREV}/${MACHINE})
PATCHFILE != ${FIND} ${PATCHDIST} -type f -name ${PATCH}.patch
_PACKAGE = ${PACKAGE_REPOSITORY}/obpf-${OSREV}-${MACHINE}-${PATCH}.tgz
.endif

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

# Default OpenBSD patch tar blob to fetch
_DISTFILES_PATCHSET ?= \
	patches/${OSREV}.tar.gz

# Any additional kernel configurations to be installed into the source tree
# These must be available from either an FTP or HTTP server
KERNELCONFS ?=

DISTFILES ?= ${_DISTFILES_OS} ${_DISTFILES_SRC} \
	${KERNELCONFS} ${_DISTFILES_PATCHSET}

_EVERYTHING = ${DISTFILES}
_DISTFILES = ${DISTFILES:C/:[0-9]$//}
ALLFILES = ${_DISTFILES}

.if exists(${PATCHDIST}/${OSREV}/common) && exists(${PATCHDIST}/${OSREV}/${MACHINE})
_PATCHFILES != \
		${FIND} ${PATCHDIST}/${OSREV}/common ${PATCHDIST}/${OSREV}/${MACHINE} \
		-type f | ${SORT} -t '/' -k 3
PATCHFILES = ${_PATCHFILES:T}
PATCHES = ${PATCHFILES:C/\.patch$//}
.endif


#####################################################
# Fetching
#####################################################
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


#####################################################
# Fetch targets
#####################################################
# Seperate target for each file fetch will retrieve
.for _F in ${ALLFILES:S@^@${FULLDISTDIR}/@}
${_F}:
	@${MKDIR} -p ${_F:H}; \
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


#####################################################
# Checksumming
#####################################################
_internal-checksum: _internal-fetch
	@cd ${CHECKSUM_FILE:H}; OK=true; \
	for file in ${_DISTFILES_OS}; do \
		filename=`basename $$file`; \
		if [ "$$filename" == "${CHECKSUM_FILE:T}" ]; then continue; fi; \
		if ! ${GREP} "^MD5 ($$filename) = " ${CHECKSUM_FILE} > /dev/null; then \
			${ECHO_MSG} ">> Warning: No checksum recorded for $$file."; \
		else \
			${GREP} "^MD5 ($$filename) = " ${CHECKSUM_FILE} | ${MD5} -c; \
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
_internal-configure: ${_CONFIGURE_COOKIE}
_internal-patch: ${_PATCH_COOKIE}
_internal-build: ${_BUILD_COOKIE}
_internal-plist: ${_PLIST_COOKIE}
_internal-fake: ${_FAKE_COOKIE}
_internal-package: ${_PACKAGE}


# The real targets. Note that some parts always get run, some parts can be
# disabled, and there are hooks to override behavior.

#####################################################
# System extraction
#####################################################
${_WRKDIR_COOKIE}:
	@${RM} -rf ${WRKDIR}
	@${MKDIR} -p ${WRKDIR}
	@${_MAKE_COOKIE} $@

${_EXTRACT_COOKIE}: ${_WRKDIR_COOKIE}
	@cd ${.CURDIR} && exec ${MAKE} _internal-checksum
	@${ECHO_MSG} "===> Extracting for ${DISTNAME}"
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
	@${MKDIR} -p ${WRKDIST}
	@for file in ${_DISTFILES_OS:C/:[0-9]$//}; do \
		if [ "`basename $$file`" == "${CHECKSUM_FILE:T}" ]; then continue; fi; \
		${ECHO_MSG} -n "===> Extracting `basename $$file` ... "; \
		${SUDO} ${TAR} xpfz ${DISTDIR}/$$file -C ${WRKDIST}; \
		${ECHO_MSG} "Done."; \
	done
	@for file in ${_DISTFILES_SRC:C/:[0-9]$//}; do \
		${ECHO_MSG} -n "===> Extracting `basename $$file` ... "; \
		${SUDO} ${TAR} xpfz ${DISTDIR}/$$file -C ${WRKDIST}/usr/src; \
		${ECHO_MSG} "Done."; \
	done
	@for file in ${KERNELCONFS:C/:[0-9]$//}; do \
		${ECHO_MSG} -n "===> Extracting Kernel config `basename $$file` ... "; \
		${SUDO} ${INSTALL} -m 0644 -o 0 -g 0 ${DISTDIR}/$$file \
			${WRKDIST}/usr/src/sys/arch/${MACHINE}/conf; \
		${ECHO_MSG} "Done."; \
	done
	@cd ${.CURDIR} && exec ${MAKE} do-extract-patches
.endif

do-extract-patches:
	@${MKDIR} -p ${PATCHDIST}
	@for file in ${_DISTFILES_PATCHSET:C/:[0-9]$//}; do \
		cd ${DISTDIR}/`dirname $$file` && \
		if ! ${MD5} -c ${WRKDIR}/.`basename $$file`.md5 > /dev/null 2>&1; then \
			${ECHO_MSG} -n "===> Extracting patchset for `basename $$file` ... "; \
			${SUDO} ${TAR} xpfz ${DISTDIR}/$$file -C ${PATCHDIST}; \
			${MD5} `basename $$file` > ${WRKDIR}/.`basename $$file`.md5; \
			${ECHO_MSG} "Done."; \
		else \
			${ECHO_MSG} "===> Extracted patchset is up to date. No new patches."; \
		fi; \
	done

_internal-sync:
	@${RM} -f ${DISTDIR}/${_DISTFILES_PATCHSET}
	@cd ${.CURDIR} && \
	exec ${MAKE} ${_DISTFILES_PATCHSET:C/:[0-9]$//:S@^@${FULLDISTDIR}/@}
	@cd ${.CURDIR} && exec ${MAKE} do-extract-patches


#####################################################
# Final system configuration
#####################################################
${_CONFIGURE_COOKIE}: ${_EXTRACT_COOKIE}
	@${ECHO_MSG} "===>  Configure chroot for ${DISTNAME}"
.if target(pre-configure)
	@cd ${.CURDIR} && exec ${MAKE} pre-configure
.endif
	@cd ${.CURDIR} && exec ${MAKE} do-configure
.if target(post-configure)
	@cd ${.CURDIR} && exec ${MAKE} post-configure
.endif
	@${_MAKE_COOKIE} $@


.if !target(do-configure)
do-configure:
	@${ECHO_MSG} -n "===> Preparing /dev ... "
	@${SUDO} ${MV} ${WRKDIST}/dev ${WRKDIST}/dev.orig
	@${SUDO} ${INSTALL} -d -m 0755 -o 0 -g 0 ${WRKDIST}/dev
	@${ECHO_MSG} "Done."
	@${ECHO_MSG} -n "===> Customizing /etc/profile ... "
	@${ECHO} 'if [ "$$SHELL" == "/bin/ksh" ]; then . /etc/ksh.kshrc; PS1="(obpf):\\W# "; fi' > ${WRKDIST}/etc/profile
	@${CP} -p ${WRKDIST}/etc/ksh.kshrc ${WRKDIST}/etc/ksh.kshrc.orig; \
		${GREP} -v 'tty=`basename $$tty`$$' ${WRKDIST}/etc/ksh.kshrc.orig > \
		${WRKDIST}/etc/ksh.kshrc && ${RM} ${WRKDIST}/etc/ksh.kshrc.orig
	@${ECHO_MSG} "Done."
.endif


#####################################################
# Chrooting
#####################################################
_internal-chroot: ${_CONFIGURE_COOKIE}
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
	-@cd ${.CURDIR} && exec ${SUDO} ${CHROOT} ${WRKDIST} ${CHROOT_SHELL}
.endif

.if !target(post-chroot)
post-chroot:
	@${ECHO_MSG} -n "===>  Removing chroot environment standard devices ... "
	@${SUDO} ${UMOUNT} -f ${WRKDIST}/dev
	@${ECHO_MSG} "Done."
.endif



# Top-level targets redirect to the real _internal-target
.for _t in fetch checksum extract configure patch build plist fake package \
	chroot clean sync
${_t}: _internal-${_t}
.endfor


_check-patchfile:
.if !defined(PATCH)
	@${ECHO_MSG}
	@${ECHO_MSG} ">> Variable PATCH (or P) not defined!"
	@${ECHO_MSG} ">> usage: make PATCH=<patchfile> <action>"
.else
	@if [ ! -e "${PATCHFILE}" ]; then \
		${ECHO_MSG} ">> A patch with name \"${PATCH}\" could not be found."; \
		${ECHO_MSG} ">> To list all patches, run: make list-patches"; \
		${ECHO_MSG}; \
		exit 1; \
	fi
.endif


#####################################################
# Patching
#####################################################
${_PATCH_COOKIE}: ${_CONFIGURE_COOKIE}
	@cd ${.CURDIR} && exec ${MAKE} _check-patchfile PATCH=${PATCH}
	@${ECHO_MSG} "===> Patching for ${PATCH}"
.if target(pre-patch)
	@cd ${.CURDIR} && exec ${MAKE} pre-patch
.endif
	@cd ${.CURDIR} && exec ${MAKE} do-patch
.if target(post-patch)
	@cd ${.CURDIR} && exec ${MAKE} post-patch
.endif
	@${_MAKE_COOKIE} $@

.if !target(do-patch)
do-patch:
	@${_MAKE_COOKIE} ${_PRE_PATCH_COOKIE}
	@cd ${WRKDIST}/usr/src && ${PATCH_CMD} -p0 < ${PATCHFILE}
.endif


#####################################################
# Building
#####################################################
.if target(${PATCH})
${_BUILD_COOKIE}: ${_PATCH_COOKIE}
	@cd ${.CURDIR} && exec ${MAKE} _check-patchfile PATCH=${PATCH}
	@${ECHO_MSG} "===> Building for ${PATCH}"
.  if target(pre-build)
	@cd ${.CURDIR} && exec ${MAKE} pre-build
.  endif
	@cd ${.CURDIR} && exec ${MAKE} pre-chroot
	@cd ${.CURDIR} && \
		exec ${SUDO} ${CHROOT} ${WRKDIST} ${KSH} -c \
		"`cd ${.CURDIR} && ${MAKE} -n ${PATCH}`"
	@cd ${.CURDIR} && exec ${MAKE} post-chroot
.  if target(post-build)
	@cd ${.CURDIR} && exec ${MAKE} post-build
.  endif
	@${_MAKE_COOKIE} $@
.else
${_BUILD_COOKIE}: ${_PATCH_COOKIE}
	@cd ${.CURDIR} && exec ${MAKE} _check-patchfile PATCH=${PATCH}
	@${ECHO_MSG} ">> No target with name \"${PATCH}\" has been defined."
	@${ECHO_MSG}
	@${ECHO_MSG} ">> Please define this target to instruct obpf how to build"
	@${ECHO_MSG} ">> the patch changes."
	@${ECHO_MSG}
	@exit 1
.endif


#####################################################
# Creating a packing list (plist)
#####################################################
${_PLIST_COOKIE}: ${_BUILD_COOKIE}
	@cd ${.CURDIR} && exec ${MAKE} _check-patchfile PATCH=${PATCH}
	@${ECHO_MSG} "===> Building plist for ${PATCH}"
.if target(pre-plist)
	@cd ${.CURDIR} && exec ${MAKE} pre-plist
.endif
	@cd ${.CURDIR} && exec ${MAKE} do-plist
.if target(post-plist)
	@cd ${.CURDIR} && exec ${MAKE} post-plist
.endif

.if !target(do-plist)
do-plist:
	@${FIND} ${WRKDIST} -path ${WRKDIST}/usr/src -prune -or \
		-path ${WRKDIST}/usr/obj -prune -or \
		-newer ${_PRE_PATCH_COOKIE} -a ! -newer ${_BUILD_COOKIE} -type f | \
		${SED} 's,^${WRKDIST},.,' | \
		${GREP} -v '/usr/src' | ${GREP} -v '/usr/obj'	> ${_PLIST_COOKIE}
.endif


#####################################################
# Faking package creation (preparing bits for packaging)
#####################################################
${_FAKE_COOKIE}: ${_PLIST_COOKIE}
	@cd ${.CURDIR} && exec ${MAKE} _check-patchfile PATCH=${PATCH}
	@${ECHO_MSG} "===> Faking package creation for ${PATCH}"
.if target(pre-fake)
	@cd ${.CURDIR} && exec ${MAKE} pre-fake
.endif
	@cd ${.CURDIR} && exec ${MAKE} do-fake
.if target(post-fake)
	@cd ${.CURDIR} && exec ${MAKE} post-fake
.endif
	@${_MAKE_COOKIE} $@

.if !target(do-fake)
do-fake:
	@${MKDIR} -p ${FAKEDIR}/${PATCH}
	@cd ${WRKDIST} && \
		${CAT} ${_PLIST_COOKIE} | ${XARGS} ${TAR} cpfz ${FAKEDIR}/${PATCH}/pack.tgz
	@cd ${FAKEDIR}/${PATCH} && ${MD5} pack.tgz > pack.tgz.md5
	@${FIND} ${PATCHDIST} -type f -name ${PATCH}.patch \
		-exec ${CP} {} ${FAKEDIR}/${PATCH} \;
	@cd ${FAKEDIR}/${PATCH} && ${MD5} ${PATCH}.patch > ${PATCH}.patch.md5
	@${CP} ${_PLIST_COOKIE} ${FAKEDIR}/${PATCH}/${PATCH}.plist
	@cd ${FAKEDIR}/${PATCH} && ${MD5} ${PATCH}.plist > ${PATCH}.plist.md5
.endif


#####################################################
# Packaging
#####################################################
${_PACKAGE}: ${_FAKE_COOKIE}
	@cd ${.CURDIR} && exec ${MAKE} _check-patchfile PATCH=${PATCH}
	@${ECHO_MSG} "===> Packaging for ${PATCH}"
.if target(pre-package)
	@cd ${.CURDIR} && exec ${MAKE} pre-package
.endif
	@cd ${.CURDIR} && exec ${MAKE} do-package
.if target(post-package)
	@cd ${.CURDIR} && exec ${MAKE} post-package
.endif

.if !target(do-package)
do-package:
	@${MKDIR} -p ${PACKAGE_REPOSITORY}
	@cd ${FAKEDIR}/ && ${TAR} cpfz ${_PACKAGE} ${PATCH}
.endif




KERNEL ?= GENERIC

#####################################################
# Cleaning up
#####################################################
_internal-clean:
	@${ECHO_MSG} "===>  Cleaning"
.if ${_clean:L:Mwork}
	@if [ -L ${WRKDIR} ]; then ${RM} -rf `readlink ${WRKDIR}`; fi
	@${RM} -rf ${WRKDIR}
.endif
.if ${_clean:L:Mdist}
	@${ECHO_MSG} "===>  Dist cleaning"
	@if cd ${DISTDIR} 2>/dev/null; then \
		${RM} -f ${ALLFILES}; \
	fi
	@${RM} -rf ${FULLDISTDIR}
.endif


#####################################################
# Convenience targets
#####################################################

distclean:
	@cd ${.CURDIR} && exec ${MAKE} clean=dist


peek-ftp:
	@${MKDIR} -p ${FULLDISTDIR}; cd ${FULLDISTDIR}; echo "cd ${FULLDISTDIR}"; \
	for i in ${MASTER_SITES:Mftp*}; do \
		echo "Connecting to $$i"; ${FETCH_CMD} $$i ; break; \
	done

_internal-list-patches:
	@${ECHO_MSG} "===> Listing patch files for ${DISTNAME}";
	@for file in ${PATCHES}; do\
		${ECHO_MSG} "$$file"; \
	done

list-patches: ${_CONFIGURE_COOKIE}
	@cd ${.CURDIR} && exec ${MAKE} _internal-list-patches

_internal-info:
	@${ECHO_MSG} "===> Instructions for ${PATCH}"
	@numlines=`${GREP} -n '^Index: ' ${PATCHFILE} | \
		${HEAD} -n 1 | ${AWK} -F':' '{print $$1}'`; \
		${HEAD} -n `${ECHO} $$(($$numlines-1))` ${PATCHFILE}

info: ${_CONFIGURE_COOKIE} _check-patchfile
	@cd ${.CURDIR} && exec ${MAKE} _internal-info PATCH=${PATCH}


#####################################################
# Shortcut build targets
#####################################################
m-obj = make obj
m-clean = make clean
m-cleandir = make cleandir
m-depend = make depend
m-includes = make includes
m-compile = make compile
m-build = make build
m = make
m-install = make install
m-std = ${m-obj} && ${m-cleandir} && ${m-depend} && ${m} && ${m-install}

m-obj-wrp = make -f Makefile.bsd-wrapper obj
m-cleandir-wrp = make -f Makefile.bsd-wrapper cleandir
m-depend-wrp = make -f Makefile.bsd-wrapper depend
m-wrp = make -f Makefile.bsd-wrapper
m-install-wrp = make -f Makefile.bsd-wrapper install

m-kernel:
	cd /usr/src/sys/arch/${MACHINE}/conf && config ${KERNEL} && \
	cd /usr/src/sys/arch/${MACHINE}/compile/${KERNEL} && \
		make clean && make depend && make && chmod 644 ./bsd

