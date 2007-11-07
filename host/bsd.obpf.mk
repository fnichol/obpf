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
MV = /bin/mv
PATCH = /usr/bin/patch
SED = /usr/bin/sed
TAR = /bin/tar
TOUCH = /usr/bin/touch
UNAME = /usr/bin/uname
XARGS = /usr/bin/xargs


#
# Global path locations
#
DISTDIR ?= ${.CURDIR}/distfiles


#
# Common commands and operations
#

# Used to print all the '===>' style prompts -- override this to turn them off
ECHO_MSG ?= ${ECHO}

# Used to fetch any remote file
FTP_KEEPALIVE ?= 0
FETCH_CMD ?= ${FTP} -V -m -k ${FTP_KEEPALIVE}


#
# Basic master sites configuration
#

# Master URL to the OpenBSD source
MASTER_SITE_OPENBSD_HOST ?= ftp://ftp.openbsd.org
MASTER_SITE_OPENBSD_DIR ?= pub/OpenBSD/${OSREV}
MASTER_SITE_OPENBSD := ${MASTER_SITE_OPENBSD_HOST}/${MASTER_SITE_OPENBSD_DIR}

# Master URL to the OpenBSD patches
MASTER_SITE_PATCH_HOST ?= ${MASTER_SITE_OPENBSD_HOST}
MASTER_SITE_PATCH_DIR ?= pub/OpenBSD/patches
MASTER_SITE_PATCH := ${MASTER_SITE_PATCH_HOST}/${MASTER_SITE_PATCH_DIR}

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

DISTFILES ?= ${_DISTFILES_OS} ${_DISTFILES_SRC}

_EVERYTHING = ${DISTFILES}

_internal-fetch:
.  if target(pre-fetch)
	@cd ${.CURDIR} && exec ${MAKE} pre-fetch
.  endif
.  if target(do-fetch)
	@cd ${.CURDIR} && exec ${MAKE} do-fetch
.  else
# What FETCH normally does:
.    if !empty(ALLFILES)
	@cd ${.CURDIR} && exec ${MAKE} ${ALLFILES:S@^@${FULLDISTDIR}/@}
.    endif
# End of FETCH
.  endif
.  if target(post-fetch)
	@cd ${.CURDIR} && exec ${MAKE} post-fetch
.  endif

# Seperate target for each file fetch will retrieve
.for _F in ${ALLFILES:S@^@${FULLDITDIR}/@}
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
# @TODO: enter MD5 sum checking on downloaded component
			exit 0; \
		fi; \
	done; exit 1
.endfor


.include <bsd.own.mk>
