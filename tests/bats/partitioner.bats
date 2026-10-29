#!/usr/bin/env bats
#
# Unit tests for the boot modes the installer offers per target disk.

setup() {
	declare -A module_options
	source "${BATS_TEST_DIRNAME}/../../tools/modules/functions/module_install_engine.sh"
	source "${BATS_TEST_DIRNAME}/../../tools/modules/system/module_partitioner.sh"
	INSTALL_LOG=/dev/null
	write_uboot_platform() { :; }
	partitioner_mtd_list() { :; }
	partitioner_emmc_device() { echo /dev/mmcblk0; }
	install_disk_in_use() { return 1; }
	unset BOOTLOADER_BOOTS_FROM
}

@test "modes: nvme without BOOTLOADER_BOOTS_FROM keeps boot on current media" {
	run partitioner_modes_for nvme nvme0n1
	[ "$status" -eq 0 ]
	[[ " $output " == *" sd split-emmc "* ]]
	[[ " $output " != *" standalone "* ]]
}

@test "modes: standalone is offered first for a role the bootloader boots from" {
	BOOTLOADER_BOOTS_FROM="nvme usb"
	run partitioner_modes_for nvme nvme0n1
	[[ " $output " == *" standalone sd split-emmc "* ]]
	run partitioner_modes_for usb sda
	[[ " $output " == *" standalone sd "* ]]
}

@test "modes: standalone is not offered for a role missing from the list" {
	BOOTLOADER_BOOTS_FROM="nvme"
	run partitioner_modes_for sata sda
	[[ " $output " != *" standalone "* ]]
}

@test "cli: standalone refuses a target the bootloader does not boot from" {
	local dev
	for dev in /dev/loop0 /dev/sda /dev/vda /dev/nvme0n1 /dev/mmcblk0 ""; do [[ -b "$dev" ]] && break; done
	[[ -n "$dev" ]] || skip "no block device to point --target at"
	partitioner_root_disk() { echo none; }
	install_detect_targets() { printf '%s\tsata\t0\t512\tsata\t0\tdisk\n' "${dev#/dev/}"; }
	partitioner_ensure_fs_tool() { return 1; }
	install_run_scenario() { echo "scenario ran"; return 99; }
	INSTALL_EXCLUDE="$BATS_TEST_TMPDIR/exclude"
	: >"$INSTALL_EXCLUDE"
	BOOTLOADER_BOOTS_FROM="nvme"
	run partitioner_cli_install --target "$dev" --boot standalone --fs ext4 --yes
	[ "$status" -eq "$INSTALL_EX_USAGE" ]
	[[ "$output" == *"--boot standalone needs a disk"* ]]
	[[ "$output" != *"scenario ran"* ]]
}

@test "cli: standalone passes the gate for a target the bootloader boots from" {
	local dev
	for dev in /dev/loop0 /dev/sda /dev/vda /dev/nvme0n1 /dev/mmcblk0 ""; do [[ -b "$dev" ]] && break; done
	[[ -n "$dev" ]] || skip "no block device to point --target at"
	partitioner_root_disk() { echo none; }
	install_detect_targets() { printf '%s\tnvme\t0\t512\tnvme\t0\tdisk\n' "${dev#/dev/}"; }
	partitioner_ensure_fs_tool() { return 1; }
	install_run_scenario() { echo "scenario ran"; return 99; }
	INSTALL_EXCLUDE="$BATS_TEST_TMPDIR/exclude"
	: >"$INSTALL_EXCLUDE"
	BOOTLOADER_BOOTS_FROM="nvme usb"
	run partitioner_cli_install --target "$dev" --boot standalone --fs ext4 --yes
	[ "$status" -eq "$INSTALL_EX_TOOL" ]
	[[ "$output" != *"--boot standalone needs a disk"* ]]
}

@test "modes: spi is offered first when BOOTLOADER_BOOTS_FROM is unset" {
	partitioner_mtd_list() { echo "mtdblock0 mtd0:U-Boot"; }
	run partitioner_modes_for nvme nvme0n1
	[[ " $output " == *" spi sd split-emmc " ]]
}

@test "modes: spi is not offered for a role missing from BOOTLOADER_BOOTS_FROM" {
	partitioner_mtd_list() { echo "mtdblock0 mtd0:U-Boot"; }
	BOOTLOADER_BOOTS_FROM="mmc"
	local role
	for role in nvme sata usb; do
		run partitioner_modes_for "$role" sda
		[[ " $output " != *" spi "* ]]
		[[ " $output " == *" sd split-emmc "* ]]
	done
	BOOTLOADER_BOOTS_FROM="nvme usb"
	run partitioner_modes_for nvme nvme0n1
	[[ " $output " == *" spi standalone sd "* ]]
	run partitioner_modes_for sata sda
	[[ " $output " != *" spi "* ]]
}

@test "cli: spi refuses a target the bootloader does not boot from" {
	local dev
	for dev in /dev/loop0 /dev/sda /dev/vda /dev/nvme0n1 /dev/mmcblk0 ""; do [[ -b "$dev" ]] && break; done
	[[ -n "$dev" ]] || skip "no block device to point --target at"
	partitioner_root_disk() { echo none; }
	install_detect_targets() { printf '%s\tnvme\t0\t512\tnvme\t0\tdisk\n' "${dev#/dev/}"; }
	partitioner_ensure_fs_tool() { return 1; }
	install_run_scenario() { echo "scenario ran"; return 99; }
	INSTALL_EXCLUDE="$BATS_TEST_TMPDIR/exclude"
	: >"$INSTALL_EXCLUDE"
	BOOTLOADER_BOOTS_FROM="mmc"
	run partitioner_cli_install --target "$dev" --boot spi --fs ext4 --yes
	[ "$status" -eq "$INSTALL_EX_USAGE" ]
	[[ "$output" == *"--boot spi needs a disk"* ]]
	[[ "$output" != *"scenario ran"* ]]
}

@test "cli: spi skips the gate when BOOTLOADER_BOOTS_FROM is unset" {
	local dev
	for dev in /dev/loop0 /dev/sda /dev/vda /dev/nvme0n1 /dev/mmcblk0 ""; do [[ -b "$dev" ]] && break; done
	[[ -n "$dev" ]] || skip "no block device to point --target at"
	partitioner_root_disk() { echo none; }
	install_detect_targets() { :; }
	partitioner_ensure_fs_tool() { return 1; }
	install_run_scenario() { echo "scenario ran"; return 99; }
	INSTALL_EXCLUDE="$BATS_TEST_TMPDIR/exclude"
	: >"$INSTALL_EXCLUDE"
	run partitioner_cli_install --target "$dev" --boot spi --fs ext4 --yes
	[ "$status" -eq "$INSTALL_EX_TOOL" ]
	[[ "$output" != *"needs a disk"* ]]
}

@test "cli: spi passes the gate for a target the bootloader boots from" {
	local dev
	for dev in /dev/loop0 /dev/sda /dev/vda /dev/nvme0n1 /dev/mmcblk0 ""; do [[ -b "$dev" ]] && break; done
	[[ -n "$dev" ]] || skip "no block device to point --target at"
	partitioner_root_disk() { echo none; }
	install_detect_targets() { printf '%s\tnvme\t0\t512\tnvme\t0\tdisk\n' "${dev#/dev/}"; }
	partitioner_ensure_fs_tool() { return 1; }
	install_run_scenario() { echo "scenario ran"; return 99; }
	INSTALL_EXCLUDE="$BATS_TEST_TMPDIR/exclude"
	: >"$INSTALL_EXCLUDE"
	BOOTLOADER_BOOTS_FROM="nvme usb"
	run partitioner_cli_install --target "$dev" --boot spi --fs ext4 --yes
	[ "$status" -eq "$INSTALL_EX_TOOL" ]
	[[ "$output" != *"needs a disk"* ]]
}

@test "modes: split-emmc is not offered when the eMMC has mounted filesystems" {
	# Turris Omnia medkit: root on the eMMC, U-Boot in SPI NOR without an mtd hook.
	install_disk_in_use() { [[ "$1" == /dev/mmcblk0 ]]; }
	partitioner_mtd_list() { echo "mtd0:U-Boot"; }
	BOOTLOADER_BOOTS_FROM="mmc"
	run partitioner_modes_for nvme nvme0n1
	[[ " $output " == *" sd " && " $output " != *" spi "* && " $output " != *" split-emmc "* ]]
	run partitioner_modes_for usb sda
	[[ " $output " == *" sd " && " $output " != *" spi "* && " $output " != *" split-emmc "* ]]
}

@test "modes: split-emmc stays offered when only the SD card is mounted" {
	install_disk_in_use() { [[ "$1" == /dev/mmcblk1 ]]; }
	run partitioner_modes_for nvme nvme0n1
	[[ " $output " == *" sd split-emmc "* ]]
}

@test "cli: split-emmc refuses an eMMC with mounted filesystems" {
	local dev
	for dev in /dev/loop0 /dev/sda /dev/vda /dev/nvme0n1 ""; do [[ -b "$dev" ]] && break; done
	[[ -n "$dev" ]] || skip "no block device to point --target at"
	partitioner_emmc_device() { echo /dev/mmcblk9; }
	install_disk_in_use() { [[ "$1" == /dev/mmcblk9 ]]; }
	partitioner_ensure_fs_tool() { return 0; }
	install_run_split() { echo "split ran"; return 99; }
	INSTALL_EXCLUDE="$BATS_TEST_TMPDIR/exclude"
	: >"$INSTALL_EXCLUDE"
	run partitioner_cli_install --target "$dev" --boot split-emmc --fs ext4 --yes
	[ "$status" -eq "$INSTALL_EX_USAGE" ]
	[[ "$output" == *"has mounted filesystems"* ]]
	[[ "$output" != *"split ran"* ]]
}

@test "cli: split-emmc passes the gate when nothing on the eMMC is mounted" {
	local dev
	for dev in /dev/loop0 /dev/sda /dev/vda /dev/nvme0n1 ""; do [[ -b "$dev" ]] && break; done
	[[ -n "$dev" ]] || skip "no block device to point --target at"
	partitioner_emmc_device() { echo /dev/mmcblk9; }
	partitioner_ensure_fs_tool() { return 0; }
	install_run_split() { echo "split ran"; return 99; }
	INSTALL_EXCLUDE="$BATS_TEST_TMPDIR/exclude"
	: >"$INSTALL_EXCLUDE"
	run partitioner_cli_install --target "$dev" --boot split-emmc --fs ext4 --yes
	[ "$status" -eq 99 ]
	[[ "$output" == *"split ran"* ]]
}

@test "split: refuses a boot device with a mounted filesystem (e.g. the running /boot)" {
	local -a devs=() d
	for d in /dev/loop0 /dev/loop1 /dev/sda /dev/sdb /dev/vda /dev/vdb /dev/nvme0n1; do [[ -b "$d" ]] && devs+=("$d"); done
	[[ ${#devs[@]} -ge 2 ]] || skip "needs two block devices"
	install_disk_in_use() { [[ "$1" == "${devs[0]}" ]]; }
	install_apply_partitions() { echo "$1" >>"$BATS_TEST_TMPDIR/partitioned"; }
	INSTALL_LOG="$BATS_TEST_TMPDIR/log"
	: >"$BATS_TEST_TMPDIR/exclude"
	run install_run_split "${devs[0]}" "${devs[1]}" ext4 "$BATS_TEST_TMPDIR/exclude"
	[ "$status" -eq "$INSTALL_EX_USAGE" ]
	[ ! -e "$BATS_TEST_TMPDIR/partitioned" ]
	grep -q "has mounted filesystems" "$INSTALL_LOG"
}

@test "split: refuses a root device with a mounted filesystem" {
	local -a devs=() d
	for d in /dev/loop0 /dev/loop1 /dev/sda /dev/sdb /dev/vda /dev/vdb /dev/nvme0n1; do [[ -b "$d" ]] && devs+=("$d"); done
	[[ ${#devs[@]} -ge 2 ]] || skip "needs two block devices"
	install_disk_in_use() { [[ "$1" == "${devs[1]}" ]]; }
	install_apply_partitions() { echo "$1" >>"$BATS_TEST_TMPDIR/partitioned"; }
	INSTALL_LOG="$BATS_TEST_TMPDIR/log"
	: >"$BATS_TEST_TMPDIR/exclude"
	run install_run_split "${devs[0]}" "${devs[1]}" ext4 "$BATS_TEST_TMPDIR/exclude"
	[ "$status" -eq "$INSTALL_EX_USAGE" ]
	[ ! -e "$BATS_TEST_TMPDIR/partitioned" ]
	grep -q "root device '${devs[1]}' has mounted filesystems" "$INSTALL_LOG"
}

@test "scenario: refuses a target with a mounted filesystem (Turris Omnia medkit eMMC)" {
	local dev
	for dev in /dev/loop0 /dev/sda /dev/vda /dev/nvme0n1 /dev/mmcblk0 ""; do [[ -b "$dev" ]] && break; done
	[[ -n "$dev" ]] || skip "no block device to point --target at"
	install_disk_in_use() { [[ "$1" == "$dev" ]]; }
	install_apply_partitions() { echo "$1" >>"$BATS_TEST_TMPDIR/partitioned"; }
	INSTALL_LOG="$BATS_TEST_TMPDIR/log"
	: >"$BATS_TEST_TMPDIR/exclude"
	run install_run_scenario emmc "$dev" ext4 "$BATS_TEST_TMPDIR/exclude"
	[ "$status" -eq "$INSTALL_EX_USAGE" ]
	[ ! -e "$BATS_TEST_TMPDIR/partitioned" ]
	grep -q "'$dev' has mounted filesystems" "$INSTALL_LOG"
}

@test "root disk: the findmnt fallback strips a btrfs subvolume suffix" {
	blkid() { :; }
	findmnt() { case "$*" in *live*) ;; *--nofsroot*) echo /dev/mmcblk0p1 ;; *) echo "/dev/mmcblk0p1[/@]" ;; esac; }
	lsblk() { [[ "${*: -1}" == /dev/mmcblk0p1 ]] && echo mmcblk0; }
	run partitioner_root_disk
	[ "$output" = "mmcblk0" ]
}
