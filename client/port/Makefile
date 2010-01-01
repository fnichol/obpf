# $OpenBSD: Makefile.template,v 1.52 2007/06/27 07:15:32 steven Exp $
# $FreeBSD/NetBSD: credit FreeBSD/NetBSD if thats where the port came from $
# Original from: credit the original author here
#
# Replace ??? with appropriate values
# Remove extraneous comments before commit.

# Reasons why the port/package shouldn't be built
#
#ONLY_FOR_ARCHS=	???
#NOT_FOR_ARCHS=		???
#SHARED_ONLY=		???
#COMES_WITH=		???
#BROKEN=		"reason"

#
# Very short description of the package, 60 chars max
#
COMMENT=		"OpenBSD Binary Patching Framework client"

#
# What port/package will be created
#
DISTNAME=		obpf-1.0

CATEGORIES=		sysutils

#HOMEPAGE=		???	URL

# where to send bitches about this port
# Put a complete email address with a real name, e.g.,
# MAINTAINER=	John Doe <doe57@machine.somewhere.org>
# if you maintain several ports, try to use the same line each time.
# MAINTAINER implies some amount of responsibility.
# If you no longer use the port, or are unwilling/unable to handle issues
# in a timely manner, *leave the field blank*.
# Default value is ports@openbsd.org, no need to fill in
MAINTAINER=		Fletcher Nichol <fletcher@silversky.ca>

PERMIT_PACKAGE_CDROM=	Yes
PERMIT_PACKAGE_FTP=	Yes
PERMIT_DISTFILES_CDROM=Yes
PERMIT_DISTFILES_FTP=	Yes

NO_CHECKSUM=	true

DISTFILES=
PATCHFILES=

fetch:

do-checksum:

do-depends:

do-extract:

do-patch:

do-configure:

do-build:

do-install:
	@${INSTALL_SCRIPT} ${FILESDIR}/obpf ${PREFIX}/bin

.include <bsd.port.mk>
