### AnyKernel3 Ramdisk Mod Script
## KernelSU with SUSFS By Numbersf
## osm0sis @ xda-developers

### AnyKernel setup
# global properties
properties() { '
kernel.string=KernelSU by KernelSU Developers
do.devicecheck=0
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=1
device.name1=
device.name2=
device.name3=
device.name4=
device.name5=
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties

### AnyKernel install
## boot shell variables
block=boot
is_slot_device=auto
ramdisk_compression=auto
patch_vbmeta_flag=auto
no_magisk_check=1

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh

if [ -L "/dev/block/bootdevice/by-name/init_boot_a" ] || [ -L "/dev/block/by-name/init_boot_a" ]; then
    split_boot
    flash_boot
else
    dump_boot
    write_boot
fi
