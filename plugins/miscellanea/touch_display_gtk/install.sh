#!/bin/bash

HW=$(awk '/VOLUMIO_HARDWARE=/' /etc/*-release | sed 's/VOLUMIO_HARDWARE=//' | sed 's/\"//g')

if [ "$HW" = "pi" ];
then

  echo "Raspberry Pi install script"

  echo "Installing fake packages for kernel, bootloader and pi lib"
  wget http://repo.volumio.org/Volumio2/Binaries/arm/libraspberrypi0_0.0.1_all.deb
  wget http://repo.volumio.org/Volumio2/Binaries/arm/raspberrypi-bootloader_0.0.1_all.deb
  wget http://repo.volumio.org/Volumio2/Binaries/arm/raspberrypi-kernel_0.0.1_all.deb
  dpkg -i libraspberrypi0_0.0.1_all.deb
  dpkg -i raspberrypi-bootloader_0.0.1_all.deb
  dpkg -i raspberrypi-kernel_0.0.1_all.deb
  rm libraspberrypi0_0.0.1_all.deb
  rm raspberrypi-bootloader_0.0.1_all.deb
  rm raspberrypi-kernel_0.0.1_all.deb

  echo "Putting on hold packages for kernel, bootloader and pi lib"
  echo "libraspberrypi0 hold" | dpkg --set-selections
  echo "raspberrypi-bootloader hold" | dpkg --set-selections
  echo "raspberrypi-kernel hold" | dpkg --set-selections

  echo "Installing Dependencies"
  sudo apt-get update
  sudo apt-get -y install

  echo "Installing Graphical environment"
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y xinit xorg openbox libexif12 xserver-xorg-legacy

  if [ -f /sys/devices/platform/rpi_backlight/backlight/rpi_backlight/brightness ]; then
    echo "Creating UDEV rule adjusting backlight brightness permissions"
    sudo echo "SUBSYSTEM==\"backlight\", RUN+=\"/bin/chmod 0666 /sys/devices/platform/rpi_backlight/backlight/rpi_backlight/brightness\"" > /etc/udev/rules.d/99-backlight.rules
    sudo /bin/chmod 0666 /sys/devices/platform/rpi_backlight/backlight/rpi_backlight/brightness
  fi

  echo "Creating /etc/X11/xorg.conf.d dir"
  sudo mkdir /etc/X11/xorg.conf.d

  echo "Creating Xorg configuration file"
  sudo echo "# This file is managed by the Touch Display plugin: Do not alter!
# It will be deleted when the Touch Display plugin gets uninstalled.
Section \"InputClass\"
        Identifier \"Touch rotation\"
        MatchIsTouchscreen \"on\"
        MatchDevicePath \"/dev/input/event*\"
        MatchDriver \"libinput|evdev\"
EndSection" > /etc/X11/xorg.conf.d/95-touch_display-plugin.conf

else

  echo "Installing Dependencies"
  sudo apt-get update
  sudo apt-get -y install

  echo "Installing Graphical environment"
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y xinit xorg openbox libexif12
fi

echo "Installing Japanese, Korean, Chinese and Taiwanese fonts"
sudo apt-get -y install fonts-arphic-ukai fonts-arphic-gbsn00lp fonts-unfonts-core

echo "Dependencies installed"

echo "Creating Kiosk Data dir"
mkdir /data/volumiokioskgtk
chown volumio:volumio /data/volumiokioskgtk

echo "Creating gtk kiosk start script"
sudo echo "#!/bin/bash
while true; do timeout 3 bash -c \"</dev/tcp/127.0.0.1/3000\" >/dev/null 2>&1 && break; done
sed -i 's/\"exited_cleanly\":false/\"exited_cleanly\":true/' /data/volumiokioskgtk/Default/Preferences
sed -i 's/\"exit_type\":\"Crashed\"/\"exit_type\":\"None\"/' /data/volumiokioskgtk/Default/Preferences
openbox-session &
while true; do
  /home/volumio/volumio_gtk/volumio
done" > /opt/volumiokioskgtk.sh
sudo /bin/chmod +x /opt/volumiokioskgtk.sh

echo "Creating Systemd Unit for Kiosk GTK"
sudo echo "[Unit]
Description=Volumio Kiosk GTK
Wants=volumio.service
After=volumio.service
[Service]
Type=simple
User=volumio
Group=volumio
ExecStart=/usr/bin/startx /etc/X11/Xsession /opt/volumiokioskgtk.sh -- -nocursor
[Install]
WantedBy=multi-user.target
" > /lib/systemd/system/volumio-kiosk-gtk.service
sudo systemctl daemon-reload

echo "Allowing volumio to start an xsession"
sudo /bin/sed -i "s/allowed_users=console/allowed_users=anybody/" /etc/X11/Xwrapper.config

#required to end the plugin install
echo "plugininstallend"
