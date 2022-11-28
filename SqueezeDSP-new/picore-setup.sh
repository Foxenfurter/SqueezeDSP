#!/bin/sh
#
#  picore-setup.sh

#create missing directories
DIR=/usr/local/slimserver/prefs/InguzEQ
if [ -d "$DIR" ]; then
	echo $DIR Exists;
else	

  # Create Directory #
  mkdir $DIR
fi
 
DIR=/usr/local/slimserver/prefs/InguzEQ/bin
if [ -d "$DIR" ]; then
	echo $DIR Exists;
else	

  # Create Directory #
  mkdir $DIR
  cd $DIR
  #get missing executables
  wget https://github.com/Foxenfurter/inguz-InguzDSP/raw/Upgrade2Net6/publishlinux-arm/InguzDSP
  chmod a+x ./InguzDSP
  wget https://raw.githubusercontent.com/Foxenfurter/inguz-InguzDSP/Upgrade2Net6/publishlinux-arm/InguzDSP.dll.config
fi

#become super boss
  ln -s /usr/local/slimserver/prefs/InguzEQ /usr/share/InguzEQ	
  ln -s "/usr/local/slimserver/prefs/InguzEQ/bin/InguzDSP" /usr/local/slimserver/Bin/armhf-linux/InguzDSP
  ln -s "/usr/local/slimserver/prefs/InguzEQ/bin/InguzDSP.dll.config"  /usr/local/slimserver/Bin/armhf-linux/InguzDSP.dll.config
  # needed for sox as server not correctly identifying directory

