#!/bin/bash

# 一些变量
export LFS=/mnt/lfs
export MAKEFLAGS='-j 4'

# 该死的颜色
color(){
    case $1 in
        red)
            echo -ne "\033[31m$2\033[0m"
        ;;
        green)
            echo -ne "\033[32m$2\033[0m"
        ;;
        yellow)
            echo -ne "\033[33m$2\033[0m"
        ;;
        skyblue)
            echo -ne "033[36m$2\033[0m"
        ;;
        blue)
            echo -ne "\033[34m$2\033[0m"
        ;;
        white)
            echo -ne "\033[37m$2\033[0m"
        ;;
        black)
            echo -ne "\033[30m$2\033[0m"
        ;;
        blackwhite)
            echo -ne "\033[40;37m$2\033[0m"
        ;;
        redwhite)
            echo -ne "\033[41;37m$2\033[0m"
        ;;
        greenwhite)
            echo ne "\033[42;37m$2\033[0m"
        ;;
        yellowwhite)
            echo -ne "\033[43;37m$2\033[0m"
        ;;
        bluewhite)
            echo -ne "\033[44;37m$2\033[0m"
        ;;
        purplewhite)
            echo -ne "\033[45;37m$2\033[0m"
        ;;
        skybluewhite)
            echo -ne "\033[46;37m$2\033[0m"
        ;;
        whiteblack)
            echo -ne "\033[47;30m$2\033[0m"
        ;;
    esac
}

setup(){
    echo -e "set +h\numask 022\nLFS=/mnt/lfs\nLC_ALL=POSIX\nLFS_TGT=\$(uname -m)-lfs-linux-gnu\nPATH=/tools/bin:/bin:/usr/bin\nexport LFS LC_ALL LFS_TGT PATH\nexport MAKEFLAGS='-j 4'" > ~/.bashrc
    source ~/.bashrc
    color yellow "输入2开始构建临时系统"
}

clean(){
    cd $LFS/sources
    rm -rf $(find . -type d -name $1\* | head -1)
}

unpack(){
    clean $1
    tar -xf $1*.tar.*
    cd $(find . -type d -name $1\* | head -1)
}

temporary_system(){

    source ~/.bashrc
    echo "LFS's log" > /tmp/lfs.log
    color red "另开终端运行tail -f /tmp/lfs.log查看编译输出\n"
    color green '(1/32) 编译Binutils中                \r'
    unpack binutils
    mkdir build
    cd build
    ../configure    --prefix=/tools            \
                    --with-sysroot=$LFS        \
                    --with-lib-path=/tools/lib \
                    --target=$LFS_TGT          \
                    --disable-nls              \
                    --disable-werror >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    case $(uname -m) in
        x86_64) mkdir -v /tools/lib && ln -sv lib /tools/lib64 ;;
    esac >> /tmp/lfs.log 2>&1
    make install >> /tmp/lfs.log 2>&1
    clean binutils

    color blue '(2/32) 编译GCC中                \r'
    unpack gcc
    tar -xf ../mpfr-3.1.5.tar.xz
    mv mpfr-3.1.5 mpfr
    tar -xf ../gmp-6.1.2.tar.xz
    mv gmp-6.1.2 gmp
    tar -xf ../mpc-1.0.3.tar.gz
    mv mpc-1.0.3 mpc
    for file in gcc/config/{linux,i386/linux{,64}}.h;do
        cp -u $file{,.orig}
        sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' -e 's@/usr@/tools@g' $file.orig > $file
        echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
        touch $file.orig
    done
    case $(uname -m) in
        x86_64)
            sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
        ;;
    esac >> /tmp/lfs.log  2>&1
    mkdir build
    cd build
    ../configure                                   \
    --target=$LFS_TGT                              \
    --prefix=/tools                                \
    --with-glibc-version=2.11                      \
    --with-sysroot=$LFS                            \
    --with-newlib                                  \
    --without-headers                              \
    --with-local-prefix=/tools                     \
    --with-native-system-header-dir=/tools/include \
    --disable-nls                                  \
    --disable-shared                               \
    --disable-multilib                             \
    --disable-decimal-float                        \
    --disable-threads                              \
    --disable-libatomic                            \
    --disable-libgomp                              \
    --disable-libmpx                               \
    --disable-libquadmath                          \
    --disable-libssp                               \
    --disable-libvtv                               \
    --disable-libstdcxx                            \
    --enable-languages=c,c++ >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    make install >> /tmp/lfs.log 2>&1
    clean gcc

    color green '(3/32) 编译Linux中                \r'
    unpack linux >> /tmp/lfs.log 2>&1
    make mrproper >> /tmp/lfs.log 2>&1
    make INSTALL_HDR_PATH=dest headers_install >> /tmp/lfs.log 2>&1
    cp -rv dest/include/* /tools/include >> /tmp/lfs.log 2>&1
    clean linux

    color blue '(4/32) 编译Glibc中                \r'
    unpack glibc
    mkdir build
    cd build
    ../configure                             \
        --prefix=/tools                    \
        --host=$LFS_TGT                    \
        --build=$(../scripts/config.guess) \
        --enable-kernel=3.2             \
        --with-headers=/tools/include      \
        libc_cv_forced_unwind=yes          \
        libc_cv_c_cleanup=yes >> /tmp/lfs.log
    make >> /tmp/lfs.log 2>&1
    make install >> /tmp/lfs.log 2>&1
    clean glibc

    color green '(5/32) 编译Libstdc++中                \r'
    unpack gcc
    mkdir build
    cd build
    ../libstdc++-v3/configure           \
    --host=$LFS_TGT                 \
    --prefix=/tools                 \
    --disable-multilib              \
    --disable-nls                   \
    --disable-libstdcxx-threads     \
    --disable-libstdcxx-pch         \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/7.2.0 >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    make install >> /tmp/lfs.log 2>&1
    clean gcc

    color blue '(6/32) 编译Binutils中                \r'
    unpack binutils
    mkdir build
    cd build
    CC=$LFS_TGT-gcc                \
    AR=$LFS_TGT-ar                 \
    RANLIB=$LFS_TGT-ranlib         \
    ../configure                   \
    --prefix=/tools            \
    --disable-nls              \
    --disable-werror           \
    --with-lib-path=/tools/lib \
    --with-sysroot >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    make install >> /tmp/lfs.log 2>&1
    make -C ld clean >> /tmp/lfs.log 2>&1
    make -C ld LIB_PATH=/usr/lib:/lib >> /tmp/lfs.log 2>&1
    cp -v ld/ld-new /tools/bin >> /tmp/lfs.log 2>&1
    clean binutils

    color green '(7/32) 编译GCC中                \r'
    unpack gcc
    cat gcc/limitx.h gcc/glimits.h gcc/limity.h > `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include-fixed/limits.h
    for file in gcc/config/{linux,i386/linux{,64}}.h
    do
    cp -u $file{,.orig}
    sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
        -e 's@/usr@/tools@g' $file.orig > $file
    echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
    touch $file.orig
    done
    case $(uname -m) in
    x86_64)
        sed -e '/m64=/s/lib64/lib/' \
            -i.orig gcc/config/i386/t-linux64
    ;;
    esac
    tar -xf ../mpfr-3.1.5.tar.xz
    mv mpfr-3.1.5 mpfr
    tar -xf ../gmp-6.1.2.tar.xz
    mv gmp-6.1.2 gmp
    tar -xf ../mpc-1.0.3.tar.gz
    mv mpc-1.0.3 mpc
    mkdir build
    cd build
    CC=$LFS_TGT-gcc                                    \
    CXX=$LFS_TGT-g++                                   \
    AR=$LFS_TGT-ar                                     \
    RANLIB=$LFS_TGT-ranlib                             \
    ../configure                                       \
        --prefix=/tools                                \
        --with-local-prefix=/tools                     \
        --with-native-system-header-dir=/tools/include \
        --enable-languages=c,c++                       \
        --disable-libstdcxx-pch                        \
        --disable-multilib                             \
        --disable-bootstrap                            \
        --disable-libgomp >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    make install >> /tmp/lfs.log 2>&1
    ln -s gcc /tools/bin/cc >> /tmp/lfs.log 2>&1
    clean gcc

    color blue '(8/32) 编译Tcl-core中                \r'
    unpack tcl
    cd unix
    ./configure --prefix=/tools >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    make install >> /tmp/lfs.log 2>&1
    chmod u+w /tools/lib/libtcl8.6.so
    make install-private-headers >> /tmp/lfs.log 2>&1
    ln -s tclsh8.6 /tools/bin/tclsh >> /tmp/lfs.log 2>&1
    clean tcl

    color green '(9/32) 编译Expect中                \r'
    unpack expect
    cp -v configure{,.orig}
    sed 's:/usr/local/bin:/bin:' configure.orig > configure
    ./configure --prefix=/tools       \
            --with-tcl=/tools/lib \
            --with-tclinclude=/tools/include >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    make SCRIPTS="" install >> /tmp/lfs.log 2>&1
    clean expect

    color blue '(10/32) 编译DejaGNU中                \r'
    unpack dejagnu
    ./configure --prefix=/tools >> /tmp/lfs.log 2>&1
    make install >> /tmp/lfs.log 2>&1
    clean dejagnu

    color green '(11/32) 编译Check中                \r'
    unpack check
    PKG_CONFIG= ./configure --prefix=/tools >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    make install >> /tmp/lfs.log 2>&1
    clean check

    color blue '(12/32) 编译Ncurses中                \r'
    unpack ncurses
    sed -i s/mawk// configure
    ./configure --prefix=/tools \
            --with-shared   \
            --without-debug \
            --without-ada   \
            --enable-widec  \
            --enable-overwrite >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    make install >> /tmp/lfs.log 2>&1
    clean ncurses

    color green '(13/32) 编译Bash中                \r'
    unpack bash
    ./configure --prefix=/tools --without-bash-malloc >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    make install >> /tmp/lfs.log 2>&1
    ln -s bash /tools/bin/sh >> /tmp/lfs.log 2>&1
    clean bash

    color blue '(14/32) 编译Bison中                \r'
    unpack bison
    ./configure --prefix=/tools >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    make install >> /tmp/lfs.log 2>&1

    color green '(15/32) 编译Bzip2中                \r'
    unpack bzip
    make >> /tmp/lfs.log 2>&1
    make PREFIX=/tools install >> /tmp/lfs.log 2>&1
    clean bzip

    color blue '(16/32) 编译Coreutils中                \r'
    unpack coreutils
    ./configure --prefix=/tools --enable-install-program=hostname >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    make install >> /tmp/lfs.log 2>&1
    clean coreutils

    color green '(17/32) 编译Diffutils中                \r'
    unpack diffutils
    ./configure --prefix=/tools >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    make install >> /tmp/lfs.log 2>&1
    clean diffutils

    color blue '(18/32) 编译File中                \r'
    unpack file
    ./configure --prefix=/tools >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    make install >> /tmp/lfs.log 2>&1
    clean file

    color green '(19/32) 编译Findutils中                \r'
    unpack findutils
    ./configure --prefix=/tools >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    make install >> /tmp/lfs.log 2>&1
    clean findutils

    color blue '(20/32) 编译Gawk中                \r'
    unpack gawk
    ./configure --prefix=/tools >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    make install >> /tmp/lfs.log 2>&1
    clean gawk

    color green '(21/32) 编译Gettext中                \r'
    unpack gettext
    cd gettext-tools
    EMACS="no" ./configure --prefix=/tools --disable-shared >> /tmp/lfs.log 2>&1
    make -C gnulib-lib >> /tmp/lfs.log 2>&1
    make -C intl pluralx.c >> /tmp/lfs.log 2>&1
    make -C src msgfmt >> /tmp/lfs.log 2>&1
    make -C src msgmerge >> /tmp/lfs.log 2>&1
    make -C src xgettext >> /tmp/lfs.log 2>&1
    cp -f src/{msgfmt,msgmerge,xgettext} /tools/bin
    clean gettext

    color blue '(22/32 编译Grep中                \r'
    unpack grep
    ./configure --prefix=/tools >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    make install >> /tmp/lfs.log 2>&1
    clean grep

    color green '(23/32) 编译Gzip中                \r'
    unpack gzip
    ./configure --prefix=/tools >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    make install >> /tmp/lfs.log 2>&1
    clean gzip

    color blue '(24/32) 编译M4中                \r'
    unpack m4
    ./configure --prefix=/tools >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    make install >> /tmp/lfs.log 2>&1
    clean m4

    color green '(25/32) 编译Make中                \r'
    unpack make
    ./configure --prefix=/tools --without-guile >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    make install >> /tmp/lfs.log 2>&1
    clean make

    color blue '(26/32) 编译Patch中                \r'
    unpack patch
    ./configure --prefix=/tools >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    make install >> /tmp/lfs.log 2>&1
    clean patch

    color green '(27/32) 编译Perl中                \r'
    unpack perl
    sed -e '9751 a#ifndef PERL_IN_XSUB_RE' \
        -e '9808 a#endif'                  \
        -i regexec.c
    sh Configure -des -Dprefix=/tools -Dlibs=-lm >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    cp -f perl cpan/podlators/scripts/pod2man /tools/bin
    mkdir -p /tools/lib/perl5/5.26.0
    cp -R lib/* /tools/lib/perl5/5.26.0
    clean perl

    color blue '(28/32) 编译Sed中                \r'
    unpack sed
    ./configure --prefix=/tools >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    make install >> /tmp/lfs.log 2>&1
    clean sed

    color green '(29/32) 编译Tar中                \r'
    unpack tar
    ./configure --prefix=/tools >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    make install >> /tmp/lfs.log 2>&1

    color blue '(30/32) 编译Texinfo中                \r'
    unpack texinfo
    ./configure --prefix=/tools >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    make install >> /tmp/lfs.log 2>&1
    clean texinfo

    color green '(31/32) 编译Util-linux中                \r'
    unpack util-linux
    ./configure --prefix=/tools                \
            --without-python               \
            --disable-makeinstall-chown    \
            --without-systemdsystemunitdir \
            --without-ncurses              \
            PKG_CONFIG="" >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    make install >> /tmp/lfs.log 2>&1
    clean util-linux

    color blue '(32/32) 编译Xz中                \r'
    unpack xz
    ./configure --prefix=/tools >> /tmp/lfs.log 2>&1
    make >> /tmp/lfs.log 2>&1
    make install >> /tmp/lfs.log 2>&1
    clean xz
    
    color yellow "输入3继续(输入2重试)"
}

main(){
    color red "输入1继续\n"
    select start in "设置环境变量" "构建临时系统" "进入临时系统" "退出";do
        case $start in
            "设置环境变量")
                setup
            ;;
            "构建临时系统")
                temporary_system
            ;;
            "进入临时系统")
                strip --strip-debug /tools/lib/* >> /tmp/lfs.log 2>&1
                /usr/bin/strip --strip-unneeded /tools/{,s}bin/* >> /tmp/lfs.log 2>&1
                rm -rf /tools/{,share}/{info,man,doc}
                color yellow "请输入root密码"
                su - root -c "/mnt/lfs/sources/chroot.sh"
            ;;
            "退出")
                exit
            ;;
        esac
    done
}

main