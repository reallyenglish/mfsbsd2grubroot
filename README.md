mfsbsd2grubroot
===============

convert mfsbsd tar file to files for grubroot, install Makefile to execute
pc-sysinstall. supports multiple hardware with TAG.

USAGE
=====

    > cp Mk/config.mk.example Mk/config.mk
    > cp templates/boot/loader.conf.common.example templates/boot/loader.conf.common
    > cp templates/Makefile.after_boot.example templates/Makefile.after_boot

edit these file.

create a TAG, beagle in this example.

    > vi templates/boot/loader.conf.beagle

run:

    # make MFSBSD_FILE=/path/to/mfsbsd/mfsbsd-9.1-RELEASE-amd64.tar TAG=beagle

extract the archive file to YOUR pxeboot directory. if you have created
PC_SYSINSTALL_CONF and AFTER_INSTALL_FILE at PC_SYSINSTALL_CONF_URL and
AFTER_INSTALL_FILE_URL, you can automatically install FreeBSD by running "make"
as root after boot.

TAG
===

this variable is mandatory. TAG is used to create hardwear-specific
configurations, such as loader.conf(5). to create and use a new TAG, create the
following files.

- templates/boot/loader.conf.${TAG}

What Makefile does
==================

- extract mfsbsd and mount the mfsroot file
- populate files, such as Makefile to start pc-sysinstall, loader.conf, etc
- create an archive suitable for grubroot

What Makefile for pc-sysinstall does
====================================

- ask user to proceed
- fetch pc-sysinstall.conf from PC_SYSINSTALL_CONF_URL
- fetch a file to execute after installation from AFTER_INSTALL_FILE_URL
- execute pc-sysinstall

both URLs support MAC address, FQDN, HOSTNAME (hostname -s) and TAG. it
searches the file in that order. for example, if PC_SYSINSTALL_CONF_URL is
http://example.org/pc-sysinstall.conf, it tries to fetch the file from:

- http://example.org/pc-sysinstall.conf.xx:xx:xx:xx:xx:xx
- http://example.org/pc-sysinstall.conf.foo.example.org
- http://example.org/pc-sysinstall.conf.foo
- http://example.org/pc-sysinstall.conf.mytag
- http://example.org/pc-sysinstall.conf

note that Makefile.after_boot does NOT automatically start installation.

Why grub?
=========

grubroot provides multiple boot options to choose. you can select older FreeBSD
RELEASE, memtest, etc. we used to have a single pxeboot environment, creating
symlinks manually to support multiple hardware. obviously, it's suboptimal and
we gave up.

Why mfsbsd?
===========

recently, FreeBSD RELEASE dropped support of mfsroot, forced users to use NFS
instead. grub does not support NFS-based pxeboot, yet. or you can blame FreeBSD
kernel not being able to mount NFS root. it expects someone to mount NFS root
for kernel and give the NFS handle to kernel.
