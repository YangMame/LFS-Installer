#!/bin/bash

# 一些变量
export LFS=/mnt/lfs
export http_proxy=127.0.0.1:8118
export https_proxy=127.0.0.1:8118

# 该死的颜色
color(){
    case $1 in
        red)
            echo -e "\033[31m$2\033[0m"
        ;;
        green)
            echo -e "\033[32m$2\033[0m"
        ;;
        yellow)
            echo -e "\033[33m$2\033[0m"
        ;;
        skyblue)
            echo -e "033[36m$2\033[0m"
        ;;
        blue)
            echo -e "\033[34m$2\033[0m"
        ;;
        white)
            echo -e "\033[37m$2\033[0m"
        ;;
        black)
            echo -e "\033[30m$2\033[0m"
        ;;
        blackwhite)
            echo -e "\033[40;37m$2\033[0m"
        ;;
        redwhite)
            echo -e "\033[41;37m$2\033[0m"
        ;;
        greenwhite)
            echo -e "\033[42;37m$2\033[0m"
        ;;
        yellowwhite)
            echo -e "\033[43;37m$2\033[0m"
        ;;
        bluewhite)
            echo -e "\033[44;37m$2\033[0m"
        ;;
        purplewhite)
            echo -e "\033[45;37m$2\033[0m"
        ;;
        skybluewhite)
            echo -e "\033[46;37m$2\033[0m"
        ;;
        whiteblack)
            echo -e "\033[47;30m$2\033[0m"
        ;;
    esac
}

# 检查系统(直接搬运修改自LFS文档)
check(){
    SH=$(readlink -f /bin/sh)
    if [ "$SH" != "/bin/bash" ];then
        color red "请将/bin/sh链接到/bin/bash"
        exit
    fi
    unset SH

    YACC=$(readlink -f /usr/bin/yacc)
    if [ "$YACC" = "/usr/bin/yacc.bison" ];then
        :
    elif [ "$YACC" = "/usr/bin/bison.yacc" ];then
        :
    else
        color red "请将/usr/bin/yacc链接到bison"
        exit
    fi
    unset YACC

    AWK=$(readlink -f /usr/bin/awk)
    if [ "$AWK" != "/usr/bin/gawk" ];then
        color red "请将/usr/bin/awk链接到/usr/bin/gawk"
        exit
    fi
    unset AWK

    color yellow "重要部分检查通过 输入2开始准备分区"
}

# 准备磁盘
disk(){
    mkdir -pv /mnt/lfs
    fdisk -l
    color green "是否调整分区?\ny) 是\nENTER) 否"
    read tmp
    if [ "$tmp" == y ];then
        color green "输入你想进行调整的磁盘,例:/dev/sda"
        read TMP
        cfdisk $TMP
    fi
    color green "输入你的根目录分区,例如:/dev/sda2"
    read TMP
    color green "是否格式化?\ny) 是\nENTER) 否"
    read tmp
    if [ "$tmp" == y ];then
        color green "      选择你想使用的文件系统\n(需要系统有你所选择的文件系统工具)"
            select type in "ext4" "btrfs" "xfs" "jfs";do
                umount $TMP > /dev/null
                mkfs.$type $TMP -f
                break
            done
    fi

    mkdir -p /mnt/lfs
    mount $TMP /mnt/lfs
    mkdir -p $LFS/sources
    chmod a+wt $LFS/sources

    mkdir -p $LFS/tools
    ln -vs $LFS/tools /

    color yellow "分区配置完成 输入3开始下载源码(输入2重试)"
}

# 下载并校验源码
sources(){
    color green "如果下载很慢 请退出并编辑此脚本删除前面的注释修改为你自己的代理 回车以继续\n(如果有些东西下载失败 重试也无效,请打开下面的链接搜索下载到/mnt/lfs/sources目录)\nhttps://mirrors.ustc.edu.cn/gentoo/distfiles/\n假如这里也没有,请谷歌搜索下载"
    read
    cd $LFS/sources
    wget http://www.linuxfromscratch.org/lfs/view/stable-systemd/wget-list
    wget --input-file=wget-list --continue --directory-prefix=$LFS/sources
    wget http://www.linuxfromscratch.org/lfs/view/stable-systemd/md5sums
    md5sum -c md5sums
    color yellow "如果源码正常下载并校验通过 输入4开始添加lfs用户(输入3重试)"
}

# 添加lfs用户用于编译
adduser(){
    groupadd lfs
    useradd -s /bin/bash -g lfs -m -k /dev/null lfs
    color yellow "设置lfs用户的密码"
    passwd lfs
    color yellow "如正常添加lfs用户 输入5开始切换用户进入下一阶段(输入4重试)"
}

# 切换到lfs用户
switch(){
    wget https://raw.githubusercontent.com/YangMame/LFS-Installer/master/temp.sh -O $LFS/sources/temp.sh
    wget https://raw.githubusercontent.com/YangMame/LFS-Installer/master/chroot.sh -O $LFS/sources/chroot.sh
    chmod +x $LFS/sources/temp.sh
    chmod +x $LFS/sources/chroot.sh
    chown lfs $LFS/tools
    chown lfs $LFS/sources
    su - lfs -c "/mnt/lfs/sources/temp.sh"
}

main(){
    if [ `whoami` != root ];then
        color red "请在root用户下运行"
        exit
    fi

    color red "请输入序号开始"
    select start in "检查系统" "准备分区" "下载源码" "添加lfs用户" "切换用户进入下一阶段" "退出";do
        case $start in
            "检查系统")
                check
            ;;
            "准备分区")
                disk
            ;;
            "下载源码")
                sources
            ;;
            "添加lfs用户")
                adduser
            ;;
            "切换用户进入下一阶段")
                switch
            ;;
            "退出")
                exit
            ;;
        esac
    done
}

main