#SDCard Creator

Script to create a beaglebone image to SD Card image

Files requirements:
MLO
*.tar.*
u-boot.img
IMAGE="zImage"
DTB="am335x-bone.dtb"

USE:

IMPORTANT:

1 - "lsblk" to find your sd card
2 - "fdisk" and then delete all partitions. Dont forget final command in
fdisk to save all changes "w"
3 - Remove the sd card and put it again
4 - Run the command line lsblk. Verify if the sdcard have "ZERO" partitions
5 - After run the mk-sdcard.sh
   chmod a+x mk-sdcard.sh
   ./mksdcard.sh /dev/sd* <name of the image (*.tar.*)>