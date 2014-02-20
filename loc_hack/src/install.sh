#!/bin/sh

OTA=com.lab126.blanket.ota

progress()
{
	lipc-send-event $OTA otaSplashProgress -i $1
	local x=48
	local y=11
	eips 0 $y "                                                ";
	eips $((($x - $(expr length "$2")) / 2)) $y "$2"
	sleep 2
}

fail()
{
	lipc-send-event $OTA otaSplashError -s "${1}"
	sleep 10
	exit 1;
}

progress 5 "Mounting main partition r/w"
mntroot rw || fail "Unable to mount main partition r/w".

progress 15 "Copying upstart config to main partition"
cp -f localization.conf /etc/upstart/ || fail "Unable to copy upstart config"


progress 25 "Copying l10n pack to user store"
[ -d /mnt/base-us/localization ] || mkdir /mnt/base-us/localization || fail "Unable to create l10n dir"
cp -f localization.pack /mnt/base-us/localization/ || fail "Unable to copy l10n pack"

bookmarks=/mnt/base-us/.active_content_sandbox/browser/resource/LocalStorage/file__0.localstorage
md5=$(md5sum $bookmarks 2>/dev/null | (read md file; echo $md))
if [ "$md5" == "e97836b4b5a37a608ff01208542ac870" -o "$md5" == "6a5d715e7411f4958da84927fbbc100b" ]
then
    progress 35 "Resetting bookmarks"
    rm -f $bookmarks
fi

progress 40 "Setting system locale"
echo -e "LANG=en_GB.UTF-8\nLC_ALL=en_GB.UTF-8" > /var/local/system/locale
sed -i 's/^locale=.*$/locale=en-GB/' /var/local/java/prefs/com.amazon.ebook.framework/prefs

progress 45 "Disabling autoupdates"
if [ -f /etc/todo/handler_registry.conf ]
then
    sed -i 's/^[^#].*=com[.]lab126[.]ota$/#\0/g' /etc/todo/handler_registry.conf
fi

progress 50 "Mounting diags partition"
/bin/mount /dev/mmcblk0p2 /mnt/mmc/ || fail "Unable to mount diags partition"

progress 55 "Setting diags root password to mario"
echo 'root:$1$szXhciXv$MWycANLcKbEravzSx7sET0:0:0:99999:7:::' > /tmp/shadow.diags
cat /mnt/mmc/etc/shadow | grep -v '^root:' >> /tmp/shadow.diags || fail "Unable to change diags root password (1)"
cp /tmp/shadow.diags /mnt/mmc/etc/shadow || fail "Unable to change diags root password (2)"


progress 60 "Creating directories"
mkdir -p /mnt/mmc/usr/local/bin
mkdir -p /mnt/mmc/usr/local/sbin
mkdir -p /mnt/mmc/usr/local/etc/dropbear

progress 65 "Copying SSH keys"
cp dropbear_*_host_key /mnt/mmc/usr/local/etc/dropbear || fail "Unable to copy SSH keys"

progress 70 "Copying binary files"
cp dropbearmulti /mnt/mmc/usr/local/bin || fail "Unable to copy dropbearmulti"
chmod 755 /mnt/mmc/usr/local/bin/dropbearmulti || fail "Unable to chmod 755 dropbearmulti"
ln -sf /usr/local/bin/dropbearmulti /mnt/mmc/usr/local/bin/dbclient || fail "Unable to link dropbearmulti to dbclient"
ln -sf /usr/local/bin/dropbearmulti /mnt/mmc/usr/local/bin/dropbearconvert || fail "Unable to link dropbearmulti to dropbearconvert"
ln -sf /usr/local/bin/dropbearmulti /mnt/mmc/usr/local/bin/dropbearkey || fail "Unable to link dropbearmulti to dropbearkey"
ln -sf /usr/local/bin/dropbearmulti /mnt/mmc/usr/local/bin/scp || fail "Unable to link dropbearmulti to scp"


progress 80 "Patching system_diags"
sed -i -e 's/rm -rf \/usr\/local/rm -rf \/DIS\/ABLED/' /mnt/mmc/opt/factory/system_diags || fail "Unable to patch system_diags"

progress 85 "Unmounting diags partition"
/bin/umount /mnt/mmc || fail "Unable to unmount diags partition"

progress 90 "Copying debrick scripts to main partition"
cp debrick /etc/upstart/ || fail "Unable to copy debrick script"
chmod 755 /etc/upstart/debrick || fail "Unable to chmod 755 debrick"
cp debrick.conf /etc/upstart/ || fail "Unable to copy debrick.conf"
chmod 644 /etc/upstart/debrick.conf || fail "Unable to chmod 644 debrick.conf"

progress 100 "Installation complete."

