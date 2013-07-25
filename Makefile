ARCH?=	amd64
RELEASE?=	9.1-RELEASE
WORKDIR?=	work
MOUNT_DIR?=	mnt
GRUBROOT_FILE?=	grubroot-${RELEASE}-${ARCH}-${TAG}.tgz
CONSOLE?=	vidconsole,comconsole
CONSOLE_SPEED?=	9600
TEMPLATES_DIR?=	templates
MESSAGE_FILE=	.message

MFSBSD_FILE?=	${.CURDIR}/../mfsbsd/mfsbsd-${RELEASE}-${ARCH}.tar

.if !defined(TAG)
IGNORE+=	variable TAG must be defined
.endif

all:	check extract_mfsbsd mount_mfsroot create_grubroot ${GRUBROOT_FILE}

check:
.if defined(IGNORE)
	@echo ${IGNORE}
	@exit 1
.endif
	@if [ ! -f ${TEMPLATES_DIR}/boot/loader.conf.${TAG} ]; then \
		echo "loder.conf for ${TAG} cannot be found at ${TEMPLATES_DIR}/boot/loader.conf.${TAG}"; \
		exit 1; \
	fi

${ARCH} ${WORKDIR} ${MOUNT_DIR} ${WORKDIR}/kernel:
	mkdir ${.TARGET}

extract_mfsbsd:	${WORKDIR}/.extract_mfsbsd_done
${WORKDIR}/.extract_mfsbsd_done:	${ARCH} ${WORKDIR}
	tar -xf ${MFSBSD_FILE} -C ${ARCH}
	touch ${WORKDIR}/.extract_mfsbsd_done

mount_mfsroot:	${ARCH}/mfsroot ${WORKDIR}/.mount_mfsroot_done
${WORKDIR}/.mount_mfsroot_done:	${MOUNT_DIR}
	mount /dev/`mdconfig -a -t vnode -f ${ARCH}/mfsroot` ${MOUNT_DIR}
	touch ${WORKDIR}/.mount_mfsroot_done

umount_mfsroot:	${WORKDIR}/.umount_mfsroot_done
${WORKDIR}/.umount_mfsroot_done:
	umount ${MOUNT_DIR}
	# remove all md(4) devices whose mount point matches ${ARCH}/mfsroot
	# XXX this is not optimal
	for i in `mdconfig -lv | cut -f1,4 | sed -e 's/[[:space:]]/|/'`; do \
		dev=`echo $${i} | cut -f1 -d'|'`; \
		mount_point=`echo $${i} | cut -f2 -d'|' `; \
		if [ "$${mount_point}" = `realpath ${ARCH}/mfsroot` ]; then \
			mdconfig -d -u $${dev}; \
		fi; \
	done
	touch ${WORKDIR}/.umount_mfsroot_done

setup_install_environment:	${WORKDIR}/.setup_install_environment_done
${WORKDIR}/.setup_install_environment_done: ${MOUNT_DIR}/root/Makefile
	touch ${WORKDIR}/.setup_install_environment_done

${MOUNT_DIR}/root/Makefile:
	sed \
		-e "s|%%AFTER_INSTALL_FILE%%|${AFTER_INSTALL_FILE}|" \
		-e "s|%%AFTER_INSTALL_FILE_URL%%|${AFTER_INSTALL_FILE_URL}|" \
		-e "s|%%PC_SYSINSTALL_CONF%%|${PC_SYSINSTALL_CONF}|" \
		-e "s|%%TAG%%|${TAG}|" \
		-e "s|%%PC_SYSINSTALL_CONF_URL%%|${PC_SYSINSTALL_CONF_URL}|" ${TEMPLATES_DIR}/Makefile.after_boot > ${MOUNT_DIR}/root/Makefile

${MOUNT_DIR}/boot/loader.conf:
	cat ${TEMPLATES_DIR}/boot/loader.conf.common ${TEMPLATES_DIR}/boot/loader.conf.${TAG}

${ARCH}/mfsroot:
	gunzip ${ARCH}/mfsroot.gz

create_grubroot:	${WORKDIR}/device.hints setup_install_environment ${WORKDIR}/kernel/kernel \
		show_grub_conf umount_mfsroot ${WORKDIR}/mfsroot

${WORKDIR}/device.hints:
	cp ${MOUNT_DIR}/boot/device.hints ${WORKDIR}/

${WORKDIR}/kernel/kernel:	${ARCH}/boot/kernel/kernel ${WORKDIR}/kernel
	cp ${ARCH}/boot/kernel/kernel ${WORKDIR}/kernel/kernel

# grub2 probably does not support compressed kernel
${ARCH}/boot/kernel/kernel:
	gunzip ${ARCH}/boot/kernel/kernel.gz

${WORKDIR}/mfsroot:
	cp ${ARCH}/mfsroot ${WORKDIR}/mfsroot

${GRUBROOT_FILE}:
	tar -C ${WORKDIR} -czf ${GRUBROOT_FILE} --exclude ".*done" .

show_conf:	
	@cat ${MESSAGE_FILE}

show_grub_conf:	${WORKDIR}/.show_grub_conf_done
${WORKDIR}/.show_grub_conf_done:
	(echo ""; \
	echo "======== example grub.conf ========"; \
	echo ""; \
	echo "menuentry \"FreeBSD ${RELEASE} ${ARCH}\" {"; \
	echo "  serial --unit=1 --speed=CHANGEME"; \
	echo "  terminal serial console"; \
	echo "  echo -e \"Fetching the kernel and UFS root...\\c\""; \
	echo "  kfreebsd /boot-${RELEASE}-${ARCH}/kernel/kernel -D -h"; \
	echo "  kfreebsd_loadenv /boot-${RELEASE}-${ARCH}/device.hints"; \
	echo "  kfreebsd_module /boot-${RELEASE}-${ARCH}/mfsroot type=mfs_root"; \
	sed -e 's/#.*//' \
		-e 's/\"//g' \
		-e 's/^/set kFreeBSD\./' < mnt/boot/loader.conf | \
		grep -v '^set kFreeBSD\.$$' | \
		sed -e 's/^/  /'; \
	echo "  echo \"Done!\""; \
	echo "  sleep 2"; \
	echo "}"; \
	echo "") >> ${MESSAGE_FILE}

clean:
# TODO mdconfig -d
# mdconfig -lv | cut -f 4
	if [ -d ${MOUNT_DIR} ]; then umount ${MOUNT_DIR} || true ; fi
	if [ -d ${ARCH}      ]; then chflags -R noschg ${ARCH}; fi
	if [ -d ${WORKDIR}   ]; then chflags -R noschg ${WORKDIR}; fi
	rm -rf ${ARCH} ${WORKDIR} ${GRUBROOT_FILE} ${MOUNT_DIR} ${MESSAGE_FILE}

install:	${WORKDIR}/.install_done
${WORKDIR}/.install_done:
	umount ${MOUNT_DIR} || true
	@if [ -d ${DESTDIR} ]; then \
		echo "DESTDIR ${DESTDIR} must not exist. please make sure it is okay to remove it and do \"rm ${DESTDIR}\""; \
		exit 1; \
	fi
	mkdir ${DESTDIR}
	tar -xf ${GRUBROOT_FILE} -C ${DESTDIR}
	touch ${WORKDIR}/.install_done

.include "Mk/config.mk"
