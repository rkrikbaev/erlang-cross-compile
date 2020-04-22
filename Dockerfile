# Target version
ARG TARGET_PLATFORM=arm-unknown-linux-gnueabihf
ARG GLIBC_VERSION=2.24

# Source toolchain
FROM vzroman/${TARGET_PLATFORM}:glibc${GLIBC_VERSION}
MAINTAINER Roman Vozzhenikov "vzroman@gmail.com"
ENV REFRESHED_AT 2020-04-17

# Environment
ARG HOST_ARCH=x86_64
ARG TARGET_PLATFORM=arm-unknown-linux-gnueabihf

# Erlang environment
ARG ZLIB_VERSION=1.2.11
ARG OPENSSL_VERSION=1.1.1f
ARG NCURSES_VERSION=6.1
ARG OTP_VERSION=22.3

# Locations
ENV SOURCES=/opt/src
ENV BUILD=/opt/build
ENV ERLANG_BUILD=$SOURCES/erlang
ENV BUILD_HOST=$ERLANG_BUILD/$HOST_ARCH
ENV BUILD_TARGET=$ERLANG_BUILD/$TARGET_PLATFORM
ENV PATH=/opt/x-tools/$TARGET_PLATFORM/bin:$PATH
ENV TARGET_SYSROOT=/opt/x-tools/$TARGET_PLATFORM/$TARGET_PLATFORM/sysroot

# Download sources
RUN mkdir -p $SOURCES && cd $_ && \
	wget http://zlib.net/zlib-$ZLIB_VERSION.tar.gz && \
	wget https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz && \
	wget http://ftp.gnu.org/pub/gnu/ncurses/ncurses-$NCURSES_VERSION.tar.gz && \
	wget http://erlang.org/download/otp_src_$OTP_VERSION.tar.gz && \
	for f in *.tar*; do tar xf $f && rm -rf $f; done

#=============HOST========================================
RUN mkdir -p $BUILD_HOST

#------------zlib--------------------------------------
RUN mkdir -p $BUILD_HOST/zlib && cd $_ && \
	$SOURCES/zlib-$ZLIB_VERSION/configure && \
	make && \
	make install

#-----------openssl------------------------------------
RUN mkdir -p $BUILD_HOST/openssl && cd $_ && \
	$SOURCES/openssl-$OPENSSL_VERSION/Configure linux-$HOST_ARCH && \
	make && \
	make install

#-----------ncurses-----------------------------------
RUN mkdir -p $BUILD_HOST/ncurses && cd $_ && \
	$SOURCES/ncurses-$NCURSES_VERSION/configure \
		--without-ada \
		--without-cxx \
		--without-cxx-binding \
		--without-manpages \
		--without-progs \
		--without-tests && \
	make && \
	make install

#----------erlang-----------------------------------
# some versions of erlang build fail because they cannot find appropriate version of zlib in /lib64 
RUN mkdir -p /lib64 && cd /lib64 && \
	cp /usr/local/lib/libz.so.1.2.11 /lib64/ && \
	rm -rf libz.so.1 && \
	ln -s libz.so.1.2.11 libz.so.1

# copy the source into a dedicated location because erlang autotools 
# make changes in the original source location which can affect 
# the target build later
RUN cp -R $SOURCES/otp_src_$OTP_VERSION $BUILD_HOST/erlang

# build erlang
RUN	cd $BUILD_HOST/erlang && \
	export ERL_TOP=`pwd` && \
	./configure \
		--disable-dynamic-ssl-lib \
		--enable-builtin-zlib \
		--with-ssl && \
	make && \
	make install

#=============TARGET========================================
RUN mkdir -p $BUILD_TARGET

#------------zlib--------------------------------------
RUN mkdir -p $BUILD_TARGET/zlib && cd $_ && \
	export CC=$TARGET_PLATFORM-gcc && \
	$SOURCES/zlib-$ZLIB_VERSION/configure \
		--prefix=$TARGET_SYSROOT && \
	make && \
	make install

#-----------openssl------------------------------------
RUN mkdir -p $BUILD_TARGET/openssl && cd $_ && \
	$SOURCES/openssl-$OPENSSL_VERSION/Configure \
		linux-generic32 \
		--prefix=$TARGET_SYSROOT \
		--openssldir=$TARGET_SYSROOT \
		--cross-compile-prefix=$TARGET_PLATFORM- \
		-fPIC && \
	make depend && \
	make && \
	make install

#-----------ncurses-----------------------------------
RUN mkdir -p $BUILD_TARGET/ncurses && cd $_ && \
	$SOURCES/ncurses-$NCURSES_VERSION/configure \
		--host=$TARGET_PLATFORM \
		--prefix=$TARGET_SYSROOT \
		--without-ada \
		--without-cxx \
		--without-cxx-binding \
		--without-manpages \
		--without-progs \
		--without-tests && \
	make && \
	make install

#----------erlang-----------------------------------
RUN mkdir -p /opt/erlang-xcomp
COPY xcomp/$TARGET_PLATFORM.conf /opt/erlang-xcomp/

# some versions of erlang build fail because they cannot find appropriate version of zlib in /lib64 
RUN mkdir -p $TARGET_SYSROOT/lib64 && cd $TARGET_SYSROOT/lib64 && \
	cp $TARGET_SYSROOT/lib/libz.so.1.2.11 $TARGET_SYSROOT/lib64/ && \
	rm -rf libz.so.1 && \
	ln -s libz.so.1.2.11 libz.so.1

# copy the source into a dedicated location
RUN cp -R $SOURCES/otp_src_$OTP_VERSION $BUILD_TARGET/erlang

# build erlang
RUN cd $BUILD_TARGET/erlang && \
	export ERL_TOP=`pwd` && \
	export ARM_SYSROOT=$TARGET_SYSROOT && \
	export ARM_TARGET=$TARGET_PLATFORM && \
	export ARM_BUILD=$ERL_TOP/erts/autoconf/config.guess && \
	./otp_build configure \
		--enable-builtin-zlib \
		--with-ssl=$TARGET_SYSROOT \
		--disable-hipe \
		--disable-dynamic-ssl-lib \
		--xcomp-conf=/opt/erlang-xcomp/$TARGET_PLATFORM.conf && \
	./otp_build boot -a

RUN cd $BUILD_TARGET/erlang && \
	./otp_build release -a /usr/local/lib/erlang_${TARGET_PLATFORM}
	
RUN cd /usr/local/lib/erlang_${TARGET_PLATFORM} && \
	./Install -minimal /usr/local/lib/erlang_${TARGET_PLATFORM}

ENTRYPOINT [ "/bin/bash" ]