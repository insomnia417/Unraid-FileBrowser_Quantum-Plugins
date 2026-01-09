#!/bin/bash

if [ "$1" = "2" ]; then
   fburl="https://github.com/gtsteffaniak/filebrowser/releases/latest/download/linux-amd64-filebrowser"
else
   fburl="https://github.com/gtsteffaniak/filebrowser/releases/download/v1.1.6-beta/linux-amd64-filebrowser"
fi;

version=`filebrowser_quantum-orig --version | head -n 1`
  echo "-------------------------------------------------------------------"
  echo "Validating connection to internet"
  echo "-------------------------------------------------------------------"
ping -q -c2 https://github.com/gtsteffaniak/filebrowser/releases/download/latest >/dev/null || ping -q -c2 1.1.1.1 >/dev/null || ping -q -c2 8.8.8.8 >/dev/null
if [ $? -eq 0 ]
then
  echo "-------------------------------------------------------------------"
  echo "Updating filebrowser_quantum"
  echo "-------------------------------------------------------------------"
  curl --connect-timeout 15 --retry 3 --retry-delay 2 --retry-max-time 30 -o /boot/config/plugins/filebrowser_quantum/install/filebrowser_quantum.zip $fburl
  unzip -o -j "/boot/config/plugins/filebrowser_quantum/install/filebrowser_quantum.zip" "*/filebrowser_quantum" -d "/boot/config/plugins/filebrowser_quantum/install"
  rm -f /boot/config/plugins/filebrowser_quantum/install/*.zip
  cp /boot/config/plugins/filebrowser_quantum/install/filebrowser_quantum /usr/sbin/filebrowser_quantum-orig.new
  mv /usr/sbin/filebrowser_quantum-orig.new /usr/sbin/filebrowser_quantum-orig
  chown root:root /usr/sbin/filebrowser_quantumrig
  chmod 755 /usr/sbin/filebrowser_quantum-orig
else
  echo ""
  echo "-------------------------------------------------------------------"
  echo "<font color='red'> Connection error - Can't fetch new version </font>"
  echo "-------------------------------------------------------------------"
  echo ""
  exit 1
fi;

current_version=`filebrowser_quantum-orig --version | head -n 1`

if [[ $version = $current_version ]]; then
  echo ""
  echo "-------------------------------------------------------------------"
  echo "<font color='red'> Update failed - Please try again </font>"
  echo "-------------------------------------------------------------------"
  echo ""
  exit 1
fi;

echo ""
echo "-------------------------------------------------------------------"
echo " filebrowser_quantum has been successfully updated "
echo "-------------------------------------------------------------------"
echo ""
