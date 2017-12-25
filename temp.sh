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
    echo "exec env -i HOME=\$HOME TERM=\$TERM PS1='\\u:\w\\$ ' /bin/bash" > ~/.bash_profile
    
    echo -e "set +h\numask 022\nLFS=/mnt/lfs\nLC_ALL=POSIX\nLFS_TGT=\$(uname -m)-lfs-linux-gnu\nPATH=/tools/bin:/bin:/usr/bin\nexport LFS LC_ALL LFS_TGT PATH\nexport MAKEFLAGS='-j 4'" > ~/.bashrc
    
    source ~/.bash_profile
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

    color green '(1/32) 编译Binutils中 运行tail -f /tmp/lfs.log查看编译输出\r'
    unpack binutils
    mkdir build
    cd build
    ../configure    --prefix=/tools            \
                    --with-sysroot=$LFS        \
                    --with-lib-path=/tools/lib \
                    --target=$LFS_TGT          \
                    --disable-nls              \
                    --disable-werror >> /tmp/lfs.log
    make >> /tmp/lfs.log
    case $(uname -m) in
        x86_64) mkdir -v /tools/lib && ln -sv lib /tools/lib64 ;;
    esac >> /tmp/lfs.log
    make install >> /tmp/lfs.log
    clean binutils

    color green '(2/32) 编译GCC中 运行tail -f /tmp/lfs.log查看编译输出\r'
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
    esac >> /tmp/lfs.log
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
    --enable-languages=c,c++ >> /tmp/lfs.log
    make >> /tmp/lfs.log
    make install >> /tmp/lfs.log
    clean gcc

    color green '(3/32) 编译Linux中 运行tail -f /tmp/lfs.log查看编译输出\r'
    unpack linux >> /tmp/lfs.log
    make mrproper >> /tmp/lfs.log
    make INSTALL_HDR_PATH=dest headers_install >> /tmp/lfs.log
    cp -rv dest/include/* /tools/include >> /tmp/lfs.log
    clean linux

    color green '(3/32) 编译Glibc中 运行tail -f /tmp/lfs.log查看编译输出\r'
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
      make >> /tmp/lfs.log
      make install >> /tmp/lfs.log
      clean glibc
}