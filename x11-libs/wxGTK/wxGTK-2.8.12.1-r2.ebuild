# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI="5"

inherit autotools eutils flag-o-matic versionator multilib-minimal

DESCRIPTION="GTK+ version of wxWidgets, a cross-platform C++ GUI toolkit"
HOMEPAGE="https://wxwidgets.org/"

BASE_PV="$(get_version_component_range 1-3)"
BASE_P="${PN}-${BASE_PV}"

# we use the wxPython tarballs because they include the full wxGTK sources and
# docs, and are released more frequently than wxGTK.
SRC_URI="mirror://sourceforge/wxpython/wxPython-src-${PV}.tar.bz2"

KEYWORDS="alpha amd64 arm ~hppa ia64 ~mips ppc ppc64 ~sh sparc x86 ~amd64-fbsd ~x86-fbsd ~amd64-linux ~x86-linux ~ppc-macos ~x86-macos"
IUSE="+X aqua doc debug gnome gstreamer odbc opengl pch sdl tiff"

SLOT="2.8"

RDEPEND="
	dev-libs/expat[${MULTILIB_USEDEP}]
	odbc?   ( dev-db/unixODBC[${MULTILIB_USEDEP}] )
	sdl?    ( media-libs/libsdl[${MULTILIB_USEDEP}] )
	X?  (
		dev-libs/glib:2[${MULTILIB_USEDEP}]
		media-libs/libpng:0=[${MULTILIB_USEDEP}]
		sys-libs/zlib[${MULTILIB_USEDEP}]
		virtual/jpeg:0=[${MULTILIB_USEDEP}]
		x11-libs/gtk+:2[${MULTILIB_USEDEP}]
		x11-libs/libSM[${MULTILIB_USEDEP}]
		x11-libs/libXinerama[${MULTILIB_USEDEP}]
		x11-libs/libXxf86vm[${MULTILIB_USEDEP}]
		x11-libs/pango[X,${MULTILIB_USEDEP}]
		gnome?  ( gnome-base/libgnomeprintui:2.2[${MULTILIB_USEDEP}] )
		gstreamer? (
			gnome-base/gconf:2[${MULTILIB_USEDEP}]
			media-libs/gstreamer:0.10[${MULTILIB_USEDEP}]
			media-libs/gst-plugins-base:0.10[${MULTILIB_USEDEP}] )
		opengl? ( virtual/opengl[${MULTILIB_USEDEP}] )
		tiff?   ( media-libs/tiff:0[${MULTILIB_USEDEP}] )
		)
	aqua? (
		x11-libs/gtk+:2[aqua=,${MULTILIB_USEDEP}]
		virtual/jpeg:0=[${MULTILIB_USEDEP}]
		tiff?   ( media-libs/tiff:0[${MULTILIB_USEDEP}] )
		)"

DEPEND="${RDEPEND}
	virtual/pkgconfig[${MULTILIB_USEDEP}]
	opengl? ( virtual/glu[${MULTILIB_USEDEP}] )
	X? (
		x11-proto/xproto[${MULTILIB_USEDEP}]
		x11-proto/xineramaproto[${MULTILIB_USEDEP}]
		x11-proto/xf86vidmodeproto[${MULTILIB_USEDEP}]
	)
"

PDEPEND=">=app-eselect/eselect-wxwidgets-0.7"

LICENSE="wxWinLL-3
		GPL-2
		odbc?	( LGPL-2 )
		doc?	( wxWinFDL-3 )"

S="${WORKDIR}/wxPython-src-${PV}"

src_prepare() {
	epatch "${FILESDIR}"/${PN}-2.8.11-unicode-odbc.patch
	epatch "${FILESDIR}"/${PN}-2.8.11-collision.patch
	epatch "${FILESDIR}"/${PN}-2.8.7-mmedia.patch              # Bug #174874
	epatch "${FILESDIR}"/${PN}-2.8.10.1-odbc-defines.patch     # Bug #310923
	epatch "${FILESDIR}"/${PN}-2.8.12.1-fix-c++14.patch        # Bug #592442

	# Bug #421851
	epatch "${FILESDIR}"/${P}-libdir.patch
	epatch "${FILESDIR}"/${P}-bakefile.patch
	epatch "${FILESDIR}"/${P}-autoconf.patch

	# prefix https://bugs.gentoo.org/394123
	sed -i -e "s:/usr:${EPREFIX}/usr:g" \
		-e '/SEARCH_INCLUDE="\\/,/"/cSEARCH_INCLUDE="'${EPREFIX}'/usr/include"' \
		configure || die

	epatch_user

	mv configure.in configure.ac || die
	eautoconf
}

multilib_src_configure() {
	local myconf

	append-flags -fno-strict-aliasing

	# X independent options
	myconf="--enable-compat26
			--enable-shared
			--enable-unicode
			--with-regex=builtin
			--with-zlib=sys
			--with-expat=sys
			$(use_enable debug)
			$(use_enable pch precomp-headers)
			$(use_with odbc odbc sys)
			$(use_with sdl)
			$(use_with tiff libtiff sys)"

	# wxGTK options
	#   --enable-graphics_ctx - needed for webkit, editra
	#   --without-gnomevfs - bug #203389
	use X && \
		myconf="${myconf}
			--enable-graphics_ctx
			--enable-gui
			--with-libpng=sys
			--with-libxpm=sys
			--with-libjpeg=sys
			$(use_enable gstreamer mediactrl)
			$(use_enable opengl)
			$(use_with opengl)
			$(use_with gnome gnomeprint)
			--without-gnomevfs"

	use aqua && \
		myconf="${myconf}
			--enable-graphics_ctx
			--enable-gui
			--with-libpng=sys
			--with-libxpm=sys
			--with-libjpeg=sys
			--with-mac
			--with-opengl"
			# cocoa toolkit seems to be broken

	# wxBase options
	if use !X && use !aqua ; then
		myconf="${myconf}
			--disable-gui"
	fi

	ECONF_SOURCE="${S}" econf ${myconf}
}

multilib_src_compile() {
	emake

	if [[ -d contrib/src ]]; then
		cd contrib/src || die
		emake
	fi
}

multilib_src_install() {
	default

	if [[ -d contrib/src ]]; then
		cd contrib/src || die
		emake DESTDIR="${D}" install
	fi
}

multilib_src_install_all() {
	cd "${S}"/docs || die
	dodoc changes.txt readme.txt todo30.txt
	newdoc base/readme.txt base_readme.txt
	newdoc gtk/readme.txt gtk_readme.txt

	if use doc; then
		dodoc -r "${S}"/docs/html
	fi

	# Stray windows locale file, causes collisions
	local wxmsw="${ED}usr/share/locale/it/LC_MESSAGES/wxmsw.mo"
	[[ -e ${wxmsw} ]] && rm "${wxmsw}"
}

pkg_postinst() {
	has_version app-eselect/eselect-wxwidgets \
		&& eselect wxwidgets update
}

pkg_postrm() {
	has_version app-eselect/eselect-wxwidgets \
		&& eselect wxwidgets update
}
