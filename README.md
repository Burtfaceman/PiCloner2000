PiCloner2000

This set of Linux scripts allows you to create a backup of a bootable media (such as an SD card in a Raspberry Pi), and restore/clone that backup to another SD card while maintaining bootability.

Raspberry Pis are mission-critical for my projects, so I want to be able to get back up and running quickly if a Pi's SD card conks out. As of June 2025, there doesn't appear to be a convenient way to make a backup of an SD card that can be restored to any old SD card. A full image backup of an SD card takes up more space than necessary (e.g. 16GB (the full capacity of the card), even if only 2GB is in use), and practically must be restored to an identical card. I wanted a better solution, so I created PiCloner2000.

What sets PiCloner2000 apart from other methods?
1. The source and destination media don't have to be the same size. It works as long as the destination card has enough space to hold what was on the source card.
2. The backup is only as large as the amount of space that was in use on the media; e.g. if a 16GB SD card had 12GB free, the backup would be 4GB (or smaller thanks to compression).
3. The backup (including boot partition and bootloader) is contained in one compressed file for easy storage.
4. Checks source and destination SD cards for file system errors using "fsck".
5. Excludes virtual and runtime directories (which you don't want in a backup; these are always recreated on boot).

Usage:
-Make the scripts executable
-Find which device (card) you want to create the backup from (or restore to) using lsblk

To create a backup:
sudo ./createbackup.sh /device/path backupfilename
e.g.1:
sudo ./createbackup.sh /dev/sda ~/sdcardbackups/mybackup #this creates a backup of the SD card found at "sda" and stores the backup at /home/yourusername/sdcardbackups/mybackup.tar.gz
e.g.2:
sudo ./createbackup.sh /dev/sdb mybackup #this creates a backup named "mybackup.tar.gz" in the current directory

To restore a backup:
sudo ./restorebackup.sh backupfilename /device/path
e.g.:
sudo ./restorebackup.sh mybackup.tar.gz /dev/sda

(Dis)claimer:
Scripts were tested on a system running Debian 12. A backup of a 16GB SD card from a Pi 3 running Raspberry Pi OS was created; the backup was restored to a slightly smaller SD card, and it functioned correctly on both a Pi 3 and a Pi Zero 2 W.
I am not a coder, and I relied heavily on ChatGPT to create these scripts, so please excuse bad practices or stylistic inconsistency.
