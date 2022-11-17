# Target version
ARG OS_VERSION=10.9
FROM debian:${OS_VERSION}

# Source toolchain
MAINTAINER Krikbaev Rustam "rk@faceplate.io"
ENV REFRESHED_AT 2022-11-17

# Environment for ..
ARG BUILD_ARCH=x86_64

# Erlang environment
ARG ZLIB_VERSION=1.2.11
ARG OPENSSL_VERSION=1.1.1f
ARG NCURSES_VERSION=6.1
ARG OTP_VERSION=22.3
ARG UNIX_ODBC_VERSION=2.3.9

# Locations
ENV SOURCES=/opt/src
ENV BUILD=/opt/build
ENV ERLANG_BUILD=$SOURCES/erlang

RUN mkdir -p $BUILD

# Install dependences
RUN apt-get -y update && \
        apt-get -y upgrade && \
        apt-get -y install build-essential && \
        apt-get -y install \
                wget \
                git \
                bzip2 \
                bison \
                help2man \
                texinfo \
                flex \
                unzip \
                file \
                gawk \
                libtool libtool-bin \
                ncurses-dev \
                cmake

# Download sources
RUN mkdir -p $SOURCES && cd $SOURCES && \
        wget https://github.com/madler/zlib/archive/refs/tags/v$ZLIB_VERSION.tar.gz && \
        wget https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz && \
        wget http://ftp.gnu.org/pub/gnu/ncurses/ncurses-$NCURSES_VERSION.tar.gz && \
        wget http://erlang.org/download/otp_src_$OTP_VERSION.tar.gz && \
        wget http://www.unixodbc.org/unixODBC-$UNIX_ODBC_VERSION.tar.gz && \
        for f in *.tar*; do tar xf $f && rm -rf $f; done

#------------zlib--------------------------------------
RUN mkdir -p $BUILD/zlib && cd $BUILD/zlib && \
        $SOURCES/zlib-$ZLIB_VERSION/configure && \
        make && \
        make install

#-----------openssl------------------------------------
RUN mkdir -p $BUILD/openssl && cd $BUILD/openssl && \
        $SOURCES/openssl-$OPENSSL_VERSION/Configure linux-$BUILD_ARCH && \
        make && \
        make install

#-----------ncurses-----------------------------------
RUN mkdir -p $BUILD/ncurses && cd $BUILD/ncurses && \
        $SOURCES/ncurses-$NCURSES_VERSION/configure \
                --without-ada \
                --without-cxx \
                --without-cxx-binding \
                --without-manpages \
                --without-progs \
                --without-tests && \
        make && \
        make install

#-----------unixODBC-----------------------------------
RUN mkdir -p $BUILD/unixODBC && cd $BUILD/unixODBC && \
        $SOURCES/unixODBC-$UNIX_ODBC_VERSION/configure  && \
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
RUN cp -R $SOURCES/otp_src_$OTP_VERSION $BUILD/erlang

# build erlang
RUN     cd $BUILD/erlang && \
        export ERL_TOP=`pwd` && \
        ./configure \
                --with-odbc \
                --disable-dynamic-ssl-lib \
                --enable-builtin-zlib \
                --with-ssl && \
        make && \
        make install

ENTRYPOINT [ "/bin/bash" ]
