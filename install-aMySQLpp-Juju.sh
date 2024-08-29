#!/bin/bash
###############################################################################
##                                                                           ##
## Auteur : José GIL                                                         ##
##                                                                           ## 
## Synopsis : Script d’installation et de configuration automatique d'un     ##
##            serveur LAMP (Apache, MySQL, PHP et phpMyAdmin) avec les       ##
##            dernières versions.                                            ##
##                                                                           ##
## Date : 20/08/2024 (v3)                                                    ##
##                                                                           ##
## Scénario :                                                                ##
##                                                                           ##
## Changements v3 (20/08/2024) :                                             ##
##   - Passage en PHP 8.3                                                    ##
##                                                                           ##
## Changements v2 (19/12/2023) :                                             ##
##   - Passage en MySQL 8.2                                                  ##
##   - Passage en PHP 8.2                                                    ##
##                                                                           ##
##      1. Mise à jour des paquets et du système si besoin                   ##
##      2. Installation de MySQL                                             ##
##      3. Installation de Apache, PHP, Git, OpenSSH-Server et Fail2Ban      ##
##                                                                           ##
###############################################################################

# Test pour savoir si exécute le script en tant que root, sinon sudo !
if [ "$(whoami)" != "root" ]; then
    SUDO=sudo
fi

# Sortir du script en cas d'erreur
set -e

# Variables 
FICHIER_DE_LOG="`echo $HOME`/post-install.log"
MOT_DE_PASSE_ADMIN_MYSQL="P@ssw0rdMySQL"

# Création du fichier de log
if [ ! -f $FICHIER_DE_LOG ]
then
    touch $FICHIER_DE_LOG
fi

# Fonction pour l'affichage écran et la journalisation dans un fichier de log
suiviInstallation() 
{
    echo "# $1"
	${SUDO} echo "# $1" &>>$FICHIER_DE_LOG
    ${SUDO} bash -c 'echo "#####" `date +"%d-%m-%Y %T"` "$1"' &>>$FICHIER_DE_LOG
}

# Fonction qui gère l'affichage d'un message de réussite
toutEstOK()
{
    echo -e "  '--> \e[32mOK\e[0m"
}

# Fonction qui gère l'affichage d'un message d'erreur et l'arrêt du script en cas de problème
erreurOnSort()
{
    echo -e "\e[41m" `${SUDO} tail -1 $FICHIER_DE_LOG` "\e[0m"
    echo -e "  '--> \e[31mUne erreur s'est produite\e[0m, consultez le fichier \e[93m$FICHIER_DE_LOG\e[0m pour plus d'informations"
    exit 1
}

# Mise à jour de la liste des paquets et mise à jour de l'installation si besoin (2 opérations)
suiviInstallation "Mise à jour de la liste des paquets et mise à jour de l'installation si besoin (2 opérations)" 
${SUDO} apt-get -y update &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort 
${SUDO} apt-get -y upgrade &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort

# Installation des prérequis pour l'installation de paquets issus de dépôts personnalisés
suiviInstallation "Installation des prérequis pour l'installation de paquets issus de dépôts personnalisés"
${SUDO} apt-get -y install apt-transport-https lsb-release ca-certificates dirmngr software-properties-common curl gnupg &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort

# Import des clés de signature des paquets sury.org/php (mainteneur dernière version de PHP/Debian)
suiviInstallation "Import des clés de signature des paquets sury.org/php (mainteneur dernière version de PHP/Debian)"
${SUDO} wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort

# Ajout du dépôt dans nos sources d'installation
suiviInstallation "Ajout du dépôt dans nos sources d'installation"
${SUDO} bash -c 'echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list' &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort

# Mise à jour de la liste des paquets et mise à jour de l'installation si besoin (2 opérations)
suiviInstallation "Mise à jour de la liste des paquets et mise à jour de l'installation si besoin (2 opérations)" 
${SUDO} apt-get -y update &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort 
${SUDO} apt-get -y upgrade &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort

# Import des clés GPG pour l'installation de MySQL
suiviInstallation "Import des clés GPG pour l'installation de MySQL"
${SUDO} curl -fsSL https://repo.mysql.com/RPM-GPG-KEY-mysql-2023 | gpg --dearmor | sudo tee /usr/share/keyrings/mysql.gpg &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort

# Ajout du repo MySQL à la liste apt
suiviInstallation "Ajout du repo MySQL à la liste apt et mise à jour (2 opérations)"
${SUDO} bash -c 'echo "deb [signed-by=/usr/share/keyrings/mysql.gpg] http://repo.mysql.com/apt/debian $(lsb_release -sc) mysql-8.0" | sudo tee /etc/apt/sources.list.d/mysql.list' &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort
${SUDO} apt-get -y update &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort 

# Installation de MySQL Server
suiviInstallation "Installation de MySQL Server (7 opérations)"
${SUDO} debconf-set-selections <<< "mysql-apt-config mysql-apt-config/select-server select mysql-8.4" &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort
${SUDO} debconf-set-selections <<< "mysql-community-server mysql-community-server/root-pass password ${MOT_DE_PASSE_ADMIN_MYSQL}" &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort
${SUDO} debconf-set-selections <<< "mysql-community-server mysql-community-server/re-root-pass password ${MOT_DE_PASSE_ADMIN_MYSQL}" &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort
${SUDO} debconf-set-selections <<< "mysql-community-server mysql-server/default-auth-override select Use Strong Password Encryption (RECOMMENDED)" &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort
${SUDO} bash -c 'export DEBIAN_FRONTEND="noninteractive"' &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort
${SUDO} apt-get -y update &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort
${SUDO} apt-get -y install mysql-community-server &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort

# Installation des services Apache, PHP, Git, OpenSSH-Server et Fail2Ban
suiviInstallation "Installation des services Apache, PHP, Git, OpenSSH-Server et Fail2Ban"
${SUDO} apt-get -y install apache2 php8.3 libapache2-mod-php8.3 php8.3-mysql git openssh-server fail2ban &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort

suiviInstallation "Instalation du projet git"
${SUDO} mysql -u root --password=${MOT_DE_PASSE_ADMIN_MYSQL} < /var/www/html/GSB/resources/bdd/gsb_restore.sql &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort
${SUDO} sed 's/html/html\/GSB\/public/' /etc/apache2/sites-available/000-default.conf &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort
# Fin
suiviInstallation "Le serveur est prêt !" && exit 0
