#!/bin/bash

# Aktualisierung der Paketquellen
echo "Aktualisiere die Paketquellen..."
sudo apt update

# Installation der benötigten Pakete
echo "Installiere erforderliche Pakete..."
sudo apt install -y apache2 libarchive-zip-perl libclone-perl \
  libconfig-std-perl libdatetime-perl libdbd-pg-perl libdbi-perl \
  libemail-address-perl libemail-mime-perl libfcgi-perl libjson-perl \
  liblist-moreutils-perl libnet-smtp-ssl-perl libnet-sslglue-perl \
  libparams-validate-perl libpdf-api2-perl librose-db-object-perl \
  librose-db-perl librose-object-perl libsort-naturally-perl \
  libstring-shellquote-perl libtemplate-perl libtext-csv-xs-perl \
  libtext-iconv-perl liburi-perl libxml-writer-perl libyaml-perl \
  libimage-info-perl libgd-gd2-perl libapache2-mod-fcgid \
  libfile-copy-recursive-perl postgresql libalgorithm-checkdigits-perl \
  libcrypt-pbkdf2-perl git libcgi-pm-perl libtext-unidecode-perl libwww-perl \
  postgresql-contrib poppler-utils libhtml-restrict-perl \
  libdatetime-set-perl libset-infinite-perl liblist-utilsby-perl \
  libdaemon-generic-perl libfile-flock-perl libfile-slurp-perl \
  libfile-mimeinfo-perl libpbkdf2-tiny-perl libregexp-ipv6-perl \
  libdatetime-event-cron-perl libexception-class-perl \
  libxml-libxml-perl libtry-tiny-perl libmath-round-perl \
  libimager-perl libimager-qrcode-perl librest-client-perl libipc-run-perl \
  libencode-imaputf7-perl libmail-imapclient-perl libuuid-tiny-perl dialog

# Latex-Installation
dialog --title "Latex installieren" --backtitle "kivitendo installieren" --yesno "Möchten Sie Latex installieren?" 7 60
response=$?
case $response in
   0) echo "Latex wird installiert."
      apt-get install -y texlive-binaries texlive-latex-recommended texlive-fonts-recommended \
      texlive-lang-german dvisvgm fonts-lmodern fonts-texgyre libptexenc1 libsynctex2 \
      libteckit0 libtexlua53 libtexluajit2 libzzip-0-13 lmodern tex-common tex-gyre \
      texlive-base latexmk texlive-latex-extra
      ;;
   1) echo "Latex wird nicht installiert."
      ;;
esac

# Passwort eingeben
dialog --clear --title "Dialog Password" --backtitle "kivitendo installieren" \
--inputbox "Wähle ein Passwd für kivitendo und postgres" 10 50 "kivitendo" 2>/tmp/kivitendo_passwd.$$
PASSWD=$(cat /tmp/kivitendo_passwd.$$)
rm -f /tmp/kivitendo_passwd.$$

# Installationsverzeichnis eingeben
dialog --clear --title "Dialog Installationsverzeichnis" --backtitle "kivitendo installieren" \
--inputbox "Pfad ohne abschließenden Slash eingeben" 10 50 "/var/www" 2>/tmp/kivitendo_dir.$$
DIR=$(cat /tmp/kivitendo_dir.$$)
rm -f /tmp/kivitendo_dir.$$

# Klonen des kivitendo-ERP-Repositories
echo "Klone das kivitendo-ERP-Repository..."
cd /var/www/
git clone https://github.com/kivitendo/kivitendo-erp.git

# Wechsel in das kivitendo-Verzeichnis und Checkout des neuesten stabilen Tags
echo "Wechsle zum neuesten stabilen Release von kivitendo..."
cd kivitendo-erp/
git checkout $(git tag -l | egrep -ve "(alpha|beta|rc)" | tail -1)
chown -R www-data: "$DIR/kivitendo-erp"

# Virtuellen Host anlegen
echo "Virtuellen Host anlegen"
if [ -f /etc/apache2/sites-available/kivitendo.apache2.conf ]; then
    echo "Lösche vorherigen Virtuellen Host"
    rm -f /etc/apache2/sites-available/kivitendo.apache2.conf
fi
cat <<EOL > /etc/apache2/sites-available/kivitendo.apache2.conf
AddHandler fcgid-script .fpl
AliasMatch ^/kivitendo/[^/]+\.pl $DIR/kivitendo-erp/dispatcher.fcgi
Alias       /kivitendo/          $DIR/kivitendo-erp/
<Directory $DIR/kivitendo-erp>
  AllowOverride All
  Options ExecCGI Includes FollowSymlinks
  AddHandler cgi-script .py
  DirectoryIndex login.pl
  AddDefaultCharset UTF-8
  Require all granted
</Directory>
<Directory $DIR/kivitendo-erp/users>
  Require all denied
</Directory>
EOL
ln -sf /etc/apache2/sites-available/kivitendo.apache2.conf /etc/apache2/sites-enabled/kivitendo.apache2.conf
service apache2 restart

# Postgres-Passwort ändern
echo "postgres Password ändern"
sudo -u postgres -H -- psql -d template1 -c "ALTER ROLE postgres WITH password '$PASSWD'"

# Konfigurationsdatei erzeugen und anpassen
echo "config/kivitendo.conf erzeugen"
cp -f $DIR/kivitendo-erp/config/kivitendo.conf.default $DIR/kivitendo-erp/config/kivitendo.conf
sed -i "s/admin_password.*$/admin_password = $PASSWD/" $DIR/kivitendo-erp/config/kivitendo.conf
sed -i "s/password =$/password = $PASSWD/" $DIR/kivitendo-erp/config/kivitendo.conf

# Abschlussmeldungen
echo "kivitendo kann jetzt im Browser unter http://localhost/kivitendo/ aufgerufen werden!"
echo "Im Adminbereich können Sie Datenbanken, Benutzer und Gruppen hinzufügen sowie weitere Konfigurationen vornehmen."
