#!/bin/bash
# ezchroot.sh
# Eric J.
# https://github.com/ericj112/ezchroot

main()
{
	shellcheck
	argcheck "$@"
	rootcheck
	createmountpoint
	intro
	getmain
	archcheck
	eficheck
	mountvfs
	echo -e "Type \e[32mexit\e[39m when done"
	chroot $mountpoint /bin/mount -a
	chroot $mountpoint
	umount -R $mountpoint
}

rootcheck()
{
	if [ "$EUID" -ne 0 ]; then
		echo -e "\e[31mError:\e[39m Run as root."
		echo -e "\e[32msudo "$0"\e[39m"
		exit
	fi
}

argcheck()
{
	if [ "$1" == "-V" ] || [ "$1" == "--version" ]; then
		version
		exit
	fi
}

version()
{
	echo -e "\e[32mez\e[39mchroot"
	echo "By Eric J."
	echo "https://github.com/ericj112/ezchroot"
}

shellcheck()
{
	pid=$(echo $$)
	ps -auxq ${pid} | grep "bash" > /dev/null 2>&1 || (echo "Error: Use bash shell, exiting.."; exit)
}
createmountpoint()
{
	mountpoint=/tmp/ezchroot$RANDOM
	mkdir $mountpoint || (echo -e "\e[31mError:\e[39m Unable to create mountpoint, exiting.."; exit)
}

contq()
{
	conta=""
	read -r conta
	conta=$(echo $conta | tr '[:upper:]' '[:lower:]')
}

intro()
{
	echo -e "Welcome to \e[32mez\e[39mchroot!"
	echo "This is meant to setup a chroot of an install automatically"
	echo -en "Continue? [Y/n]: "
	contq
	if [ "$conta" != "yes" ] && [ "$conta" != "y" ]; then
		exit
	fi
}

getmain()
{
	partsfound=$(blkid | grep -c ext)
	echo "$partsfound possible installation(s) found"
	for partnm in $(blkid | grep ext | cut -d: -f1); do
		echo "Checking $partnm partition.."
		mount $partnm $mountpoint

		if [ ! -f "$mountpoint/etc/fstab" ]; then
			sleep 0.2
			umount $mountpoint
			continue
		fi

		if [ -f "${mountpoint}/etc/issue" ]; then
			echo -e "\e[33m"
			echo "Found $(cat ${mountpoint}/etc/issue)"
			echo -e "\e[39m"
		else
			echo "Found unknown distro"
		fi

		echo -n "Continue? [Y/n]: "
		contq
		if [ "$conta" != "yes" ] && [ "$conta" != "y" ]; then
			umount $mountpoint
			continue
		else
			selected=y
			break
		fi

	done

	if [ "$selected" != "y" ]; then
		echo "No installation found or selected"
		exit
	fi
}

archcheck()
{
	[ -d "/lib64" ] && livearch=64 || livearch=32
	[ -d "$mountpoint/lib64" ] && installarch=64 || installarch=32
	if [ $installarch -ne $livearch ]; then
		echo -e "\e[31mError:\e[39m Arch mismatch between live session and selected install"
		echo -e "Live session is ${livearch}-bit, install is ${installarch}-bit"
		echo -e "Use a \e[32m${installarch}-bit\e[39m live usb"
		umount $mountpoint
		exit
	fi

	echo -e "Arch check [ \e[32mOK\e[39m ]"
}

eficheck()
{
	[ -d "/sys/firmware/efi" ] && liveefi="EFI" || liveefi="legacy"

	if [[ $(grep -v ^# $mountpoint/etc/fstab | grep "boot.*vfat") ]]; then
		installefi="EFI"
	else
		installefi="legacy"
	fi

	if [ "$installefi" != "$liveefi" ]; then
		echo -e "\e[33mWarning:\e[39m EFI mismatch"
		echo "Live session is booted in $liveefi mode"
		echo "Install is in $installefi mode"
	else
		echo -e "EFI check [ \e[32mOK\e[39m ]"
	fi
}

mountvfs()
{
	echo -n "Mounting virtual filesystems.. "
	exitst=0
	for vfs in /dev /dev/pts /proc /sys /run; do
		echo -n "$vfs "
		mount --bind $vfs ${mountpoint}${vfs}
		exitst=$((exitst+$(echo $?)))
	done

	if [ "$exitst" -eq 0 ]; then
		echo -e "[ \e[32mOK\e[39m ]"
	else
		echo -e "[ \e[33mFAILED\e[39m ]"
	fi
}
main "$@"
