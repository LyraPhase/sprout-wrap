#!/bin/bash
# Reference: https://web.archive.org/web/20211229052616/https://blog.frd.mn/install-os-x-10-10-yosemite-in-virtualbox/

# Before we can use the vanilla Yosemite Installer in VirtualBox, we have to customize the InstallESD using iesd first as well as convert it into a sparse image (UDSP format):
iesd -i "/Applications/Install OS X Yosemite.app" -o yosemite.dmg -t BaseSystem
hdiutil convert yosemite.dmg -format UDSP -o yosemite.sparseimage

# Now we need to mount both the original InstallESD and the customized sparse image that we just generated ...
hdiutil mount "/Applications/Install OS X Yosemite.app/Contents/SharedSupport/InstallESD.dmg"
hdiutil mount yosemite.sparseimage

# ... to copy the missing original base system files back into the customized InstallESD:
cp "/Volumes/OS X Install ESD/BaseSystem."* "/Volumes/OS X Base System/"

# Unmount both the InstallESD and the sparse image:
hdiutil unmount "/Volumes/OS X Install ESD/"
hdiutil unmount "/Volumes/OS X Base System/"

# As well as the mounted disks via diskutil and your Terminal:
diskutil unmountDisk $(diskutil list | grep "OS X Base System" -B 4 | head -1)
diskutil unmountDisk $(diskutil list | grep "OS X Install ESD" -B 4 | head -1)

# Note: If that doesn't work and you get a "resource busy" message in step 12, try using the Disk Utility.app:

# Finally we can convert it back into a .dmg file (UDZO format):
hdiutil convert yosemite.sparseimage -format UDZO -o yosemitefixed.dmg


# Installation in VirtualBox
#
# Open VirtualBox, insert the customized yosemitefixed.dmg in the CD-ROM drive of your guest system and make sure to adjust the chipset to "PIIX3".
#
# Now you can start up your VM, open the Disk Utility.app within the installer and create a new HFS+ partition to install a fresh copy of Yosemite.