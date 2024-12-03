# Principes

## Gestion du lab

Sur un poste où Docker est installé :

1. Récupérer les scripts via git clone (git clone <https://github.com/madmohsii/sio.git>).
1. Se déplacer dans le dossier "lab1" créé.
1. Usage du script "gestion_lab1.sh" :

``` bash
    Usage: bash gestion_lab1.sh -c|-l|d|s|r|i <type de l'image>|h
    -c Crée le laboratoire. Ce dernier sera lancé à l'issue de la création.
    -l Lance un laboratoire préalablement stoppé.
    -d Supprime le laboratoire. Les volumes sont également supprimés.
    -s Stoppe le laboratoire.
    -r Redémarre un laboratoire actif.
    -i Crée une image personnalisée (mettre le type de l'image en majuscule) -i ROUTEUR|SERVEUR|CLIENT|KALI|BASE.
    -h Détail des options.
```

> Tapper bash gestion_lab1.sh -c
> Il suffit de fournir le fichier gestion_lab1.sh aux étudiants.

Le script "gestion_lab1.sh" permet de créer un laboratoire opérationnel correspondant au schéma suivant :

![Schéma réseau du laboratoire 1 - Kali-Linux](schema_reseau_lab1_docker.drawio.png "Schéma réseau du laboratoire 1 - Kali-Linux").

> Il est possible de personnaliser le laboratoire en modifiant les variables.

## Accessibilité des conteneurs

### SSH

Tous les conteneurs sont accessibles via ssh à partir de l'hôte et de l'extérieur.

À partir de l'hôte les conteneurs sont directement accessibles via leur adresse IP interne sur le port 22, par exemple pour l'attaquant Kali : ssh etusio@192.168.56.12

À partir d'une machine externe les conteneurs sont accessibles via l'adresse IP de l'hôte sur le port défini dans le fichier variables, par exemple pour l'attaquant Kali : ssh etusio@192.168.60.111 -p 32222 (avec 192.168.60.111 l'adresse IP du serveur Docker).

### Interface graphique via RDP

Les conteneurs correspondants aux clients légitimes et à l'attaquant Kali sont dotés d'une interface graphique accessible via le protocole RDP.

Il est nécessaire de configurer un client de bureau à distance.

À partir de l'hôte les conteneurs sont directement accessibles via leur adresse IP interne sur le port 3389.

À partir d'une machine externe les conteneurs sont accessibles via l'adresse IP de l'hôte sur le port défini dans le fichier variables, par exemple pour l'attaquant Kali : 33389.

> Pour le client REMMINA (sur Linux), une configuration supplémentaire doit être faite :
>
> - ouvrir les paramètres de connexion pour le profil de connexion ;
> - accéder à "Avancé" et sélectionner "Cache des glyphes" et "Assouplir les vérifications des ordres".


