#!/bin/bash

set +e

CURRENT_HOSTNAME=`cat /etc/hostname | tr -d " \t\n\r"`
if [ -f /usr/lib/raspberrypi-sys-mods/imager_custom ]; then
   /usr/lib/raspberrypi-sys-mods/imager_custom set_hostname raspberrypi
else
   echo raspberrypi >/etc/hostname
   sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\traspberrypi/g" /etc/hosts
fi
FIRSTUSER=`getent passwd 1000 | cut -d: -f1`
FIRSTUSERHOME=`getent passwd 1000 | cut -d: -f6`
if [ -f /usr/lib/raspberrypi-sys-mods/imager_custom ]; then
   /usr/lib/raspberrypi-sys-mods/imager_custom enable_ssh -k 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQD1+R36763ootK1cvpG34rZhQdv0mmHMjAUWe5UL+FNVebU57f8alS9pVM+GkX/sgWGgoeru5pkORJseIr2pTDxBlo1KZVZt9w/Jcauxf38x15VQ10Zlgv9qErTWnXbcY2LnFRqqhGpDyQFk3zHtPiRAI60UWKFZ8KrXi+cYw3qNQvZUxrHCvAPsYpi6A3o1hGLUgyZx6Ekjv0q6pFicFPTmythGjNDNE+xgs41aFrHBXr32GuY0A8kJmvJreziy9H9YC5YTDY7d7LAU0ZmP2H49y6oyorXniEpPCPijNiOf871KEfsgCJ/lOBicGxnOvLJYzTF1lurwZRaQ59q229P3raTwbNpwWeHIWDFqtlJFs523x/jCkqCjvU+Tq/VjskxHJaJhXaEheXFKhRADQSXgQUA5I2Nt/IgsJ8RDi0JnYM9+hkgs+tOxL7SkUaMDWo4Dys1dk5OKBx+W+JX8cenPd2ITCdLmTVyVVVUh0m7XIKibW/FWjZOYLNtpEIZTIADhdrLKzuoXd+gRlFwjNYIqBi5CQfMXMSy228uiLzNLoPXXiaDS8ACNk2jSq1Wp6Ca/0AM4JhLt0jGy+hkQ7e/MfGQOxVJoE86ZxCA4nwwfhskOE/GQNYIOJvBaCGG7n6WTdjMhE7mrSa94WMau1EjGto98adDAASwttIr7uOa/Q== gernot.ullrich@gmx.de' 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQD1+R36763ootK1cvpG34rZhQdv0mmHMjAUWe5UL+FNVebU57f8alS9pVM+GkX/sgWGgoeru5pkORJseIr2pTDxBlo1KZVZt9w/Jcauxf38x15VQ10Zlgv9qErTWnXbcY2LnFRqqhGpDyQFk3zHtPiRAI60UWKFZ8KrXi+cYw3qNQvZUxrHCvAPsYpi6A3o1hGLUgyZx6Ekjv0q6pFicFPTmythGjNDNE+xgs41aFrHBXr32GuY0A8kJmvJreziy9H9YC5YTDY7d7LAU0ZmP2H49y6oyorXniEpPCPijNiOf871KEfsgCJ/lOBicGxnOvLJYzTF1lurwZRaQ59q229P3raTwbNpwWeHIWDFqtlJFs523x/jCkqCjvU+Tq/VjskxHJaJhXaEheXFKhRADQSXgQUA5I2Nt/IgsJ8RDi0JnYM9+hkgs+tOxL7SkUaMDWo4Dys1dk5OKBx+W+JX8cenPd2ITCdLmTVyVVVUh0m7XIKibW/FWjZOYLNtpEIZTIADhdrLKzuoXd+gRlFwjNYIqBi5CQfMXMSy228uiLzNLoPXXiaDS8ACNk2jSq1Wp6Ca/0AM4JhLt0jGy+hkQ7e/MfGQOxVJoE86ZxCA4nwwfhskOE/GQNYIOJvBaCGG7n6WTdjMhE7mrSa94WMau1EjGto98adDAASwttIr7uOa/Q== gernot.ullrich@gmx.de'
else
   install -o "$FIRSTUSER" -m 700 -d "$FIRSTUSERHOME/.ssh"
   install -o "$FIRSTUSER" -m 600 <(printf "'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQD1+R36763ootK1cvpG34rZhQdv0mmHMjAUWe5UL+FNVebU57f8alS9pVM+GkX/sgWGgoeru5pkORJseIr2pTDxBlo1KZVZt9w/Jcauxf38x15VQ10Zlgv9qErTWnXbcY2LnFRqqhGpDyQFk3zHtPiRAI60UWKFZ8KrXi+cYw3qNQvZUxrHCvAPsYpi6A3o1hGLUgyZx6Ekjv0q6pFicFPTmythGjNDNE+xgs41aFrHBXr32GuY0A8kJmvJreziy9H9YC5YTDY7d7LAU0ZmP2H49y6oyorXniEpPCPijNiOf871KEfsgCJ/lOBicGxnOvLJYzTF1lurwZRaQ59q229P3raTwbNpwWeHIWDFqtlJFs523x/jCkqCjvU+Tq/VjskxHJaJhXaEheXFKhRADQSXgQUA5I2Nt/IgsJ8RDi0JnYM9+hkgs+tOxL7SkUaMDWo4Dys1dk5OKBx+W+JX8cenPd2ITCdLmTVyVVVUh0m7XIKibW/FWjZOYLNtpEIZTIADhdrLKzuoXd+gRlFwjNYIqBi5CQfMXMSy228uiLzNLoPXXiaDS8ACNk2jSq1Wp6Ca/0AM4JhLt0jGy+hkQ7e/MfGQOxVJoE86ZxCA4nwwfhskOE/GQNYIOJvBaCGG7n6WTdjMhE7mrSa94WMau1EjGto98adDAASwttIr7uOa/Q== gernot.ullrich@gmx.de'\n'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQD1+R36763ootK1cvpG34rZhQdv0mmHMjAUWe5UL+FNVebU57f8alS9pVM+GkX/sgWGgoeru5pkORJseIr2pTDxBlo1KZVZt9w/Jcauxf38x15VQ10Zlgv9qErTWnXbcY2LnFRqqhGpDyQFk3zHtPiRAI60UWKFZ8KrXi+cYw3qNQvZUxrHCvAPsYpi6A3o1hGLUgyZx6Ekjv0q6pFicFPTmythGjNDNE+xgs41aFrHBXr32GuY0A8kJmvJreziy9H9YC5YTDY7d7LAU0ZmP2H49y6oyorXniEpPCPijNiOf871KEfsgCJ/lOBicGxnOvLJYzTF1lurwZRaQ59q229P3raTwbNpwWeHIWDFqtlJFs523x/jCkqCjvU+Tq/VjskxHJaJhXaEheXFKhRADQSXgQUA5I2Nt/IgsJ8RDi0JnYM9+hkgs+tOxL7SkUaMDWo4Dys1dk5OKBx+W+JX8cenPd2ITCdLmTVyVVVUh0m7XIKibW/FWjZOYLNtpEIZTIADhdrLKzuoXd+gRlFwjNYIqBi5CQfMXMSy228uiLzNLoPXXiaDS8ACNk2jSq1Wp6Ca/0AM4JhLt0jGy+hkQ7e/MfGQOxVJoE86ZxCA4nwwfhskOE/GQNYIOJvBaCGG7n6WTdjMhE7mrSa94WMau1EjGto98adDAASwttIr7uOa/Q== gernot.ullrich@gmx.de'\n") "$FIRSTUSERHOME/.ssh/authorized_keys"
   echo 'PasswordAuthentication no' >>/etc/ssh/sshd_config
   systemctl enable ssh
fi
if [ -f /usr/lib/userconf-pi/userconf ]; then
   /usr/lib/userconf-pi/userconf 'pi' '$5$hH2NnnlZtG$4aSKY3ugiu7jopYLBG45gJwwYFatk0xQwypIzz8x.2/'
else
   echo "$FIRSTUSER:"'$5$hH2NnnlZtG$4aSKY3ugiu7jopYLBG45gJwwYFatk0xQwypIzz8x.2/' | chpasswd -e
   if [ "$FIRSTUSER" != "pi" ]; then
      usermod -l "pi" "$FIRSTUSER"
      usermod -m -d "/home/pi" "pi"
      groupmod -n "pi" "$FIRSTUSER"
      if grep -q "^autologin-user=" /etc/lightdm/lightdm.conf ; then
         sed /etc/lightdm/lightdm.conf -i -e "s/^autologin-user=.*/autologin-user=pi/"
      fi
      if [ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ]; then
         sed /etc/systemd/system/getty@tty1.service.d/autologin.conf -i -e "s/$FIRSTUSER/pi/"
      fi
      if [ -f /etc/sudoers.d/010_pi-nopasswd ]; then
         sed -i "s/^$FIRSTUSER /pi /" /etc/sudoers.d/010_pi-nopasswd
      fi
   fi
fi
if [ -f /usr/lib/raspberrypi-sys-mods/imager_custom ]; then
   /usr/lib/raspberrypi-sys-mods/imager_custom set_wlan 'FRITZ!Box 7690 UL' '7708c79428aea005ca2146461fd4776e66dc24c49018c41f55dcbdbe898ade0e' 'DE'
else
cat >/etc/wpa_supplicant/wpa_supplicant.conf <<'WPAEOF'
country=DE
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
ap_scan=1

update_config=1
network={
	ssid="FRITZ!Box 7690 UL"
	psk=7708c79428aea005ca2146461fd4776e66dc24c49018c41f55dcbdbe898ade0e
}

WPAEOF
   chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf
   rfkill unblock wifi
   for filename in /var/lib/systemd/rfkill/*:wlan ; do
       echo 0 > $filename
   done
fi
if [ -f /usr/lib/raspberrypi-sys-mods/imager_custom ]; then
   /usr/lib/raspberrypi-sys-mods/imager_custom set_keymap 'de'
   /usr/lib/raspberrypi-sys-mods/imager_custom set_timezone 'Europe/Berlin'
else
   rm -f /etc/localtime
   echo "Europe/Berlin" >/etc/timezone
   dpkg-reconfigure -f noninteractive tzdata
cat >/etc/default/keyboard <<'KBEOF'
XKBMODEL="pc105"
XKBLAYOUT="de"
XKBVARIANT=""
XKBOPTIONS=""

KBEOF
   dpkg-reconfigure -f noninteractive keyboard-configuration
fi
rm -f /boot/firstrun.sh
sed -i 's| systemd.run.*||g' /boot/cmdline.txt
exit 0
