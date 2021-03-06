#!/bin/sh

VERSION='29072020' 

/usr/sbin/pkg bootstrap
/usr/sbin/pkg update

rm /usr/local/etc/pkg/repos/FreeBSD.conf

mkdir -p /usr/local/etc/pkg/repos

cat <<EOF > /usr/local/etc/pkg/repos/FreeBSD.conf
FreeBSD: {
  url: "pkg+http://pkg.FreeBSD.org/${ABI}/latest",
  mirror_type: "srv",
  signature_type: "fingerprints",
  fingerprints: "/usr/share/keys/pkg",
  enabled: yes
}
EOF

sed -i.bak '/FreeBSD/d' /usr/local/etc/pkg/repos/pfSense.conf

/usr/sbin/pkg update -r FreeBSD
/usr/sbin/pkg install net/samba410 2> /dev/null

/usr/sbin/pkg unlock pkg
/usr/sbin/pkg unlock pfSense-2.4.5

mkdir -p /var/db/samba4/winbindd_privileged
chown -R :proxy /var/db/samba4/winbindd_privileged
chmod -R 0750 /var/db/samba4/winbindd_privileged

fetch -o /usr/local/pkg -q https://raw.githubusercontent.com/tinto09/ntlm-pfsense/master/samba.inc
fetch -o /usr/local/pkg -q https://raw.githubusercontent.com/tinto09/ntlm-pfsense/master/samba.xml

/usr/local/sbin/pfSsh.php <<EOF
\$samba = false;
foreach (\$config['installedpackages']['service'] as \$item) {
  if ('samba' == \$item['name']) {
    \$samba = true;
    break;
  }
}
if (\$samba == false) {
	\$config['installedpackages']['service'][] = array(
	  'name' => 'samba',
	  'rcfile' => 'samba.sh',
	  'executable' => 'smbd',
	  'description' => 'Samba daemon'
  );
}
\$samba = false;
foreach (\$config['installedpackages']['menu'] as \$item) {
  if ('Samba (AD)' == \$item['name']) {
    \$samba = true;
    break;
  }
}
if (\$samba == false) {
  \$config['installedpackages']['menu'][] = array(
    'name' => 'Samba (AD)',
    'section' => 'Services',
    'url' => '/pkg_edit.php?xml=samba.xml'
  );
}
write_config();
exec;
exit
EOF


if [ ! "$(/usr/sbin/pkg info | grep pfSense-pkg-squid)" ]; then
	/usr/sbin/pkg install -r pfSense pfSense-pkg-squid
fi
cd /usr/local/pkg
fetch -o - -q https://raw.githubusercontent.com/tinto09/ntlm-pfsense/master/squid_winbind_auth.patch | patch -b -p0 -f
fetch -o /usr/local/pkg -q https://raw.githubusercontent.com/tinto09/ntlm-pfsense/master/squid.inc

if [ ! -f "/usr/local/etc/smb4.conf" ]; then
	touch /usr/local/etc/smb4.conf
fi
cp -f /usr/local/bin/ntlm_auth /usr/local/libexec/squid/ntlm_auth

/etc/rc.d/ldconfig restart

echo "$VERSION" > /etc/samba.patch.version
