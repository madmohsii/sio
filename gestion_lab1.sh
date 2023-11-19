#!/bin/bash
# shellcheck disable=SC2181,SC2001
# shellcheck source=/dev/null
#
# #############################
# LABO KALI - LABORATOIRE 1
# #############################
#
#
# Ce script permet de créer, lancer, stopper, relancer, supprimer le laboratoire
# Ainsi que de créer des images personnalisées
#
#
# #############################
# Définition des variables
# #############################

# Ports RDP port
RDP_PORT_CLIENT=23389
RDP_PORT_KALI=33389

# Ports SSH
SSH_PORT_SERVEUR=12222
SSH_PORT_CLIENT=22222
SSH_PORT_KALI=32222
SSH_PORT_ROUTEUR=42222

# Méta-paquets KALI
# Options: "arm" "core" "default" "everything" "firmware" "headless" "labs" "large" "nethunter"
# Défaut : core dans la LAB 1
KALI_PKG="core"

# Configuration du réseau
NOM_RESEAU_INTERNE="bridge_interne_lab"
# La configuration du DNS doit être modifiée si les valeurs ci-dessous sont modifiées
# Modifier la variable IP_RESEAU_INTERNE implique la suppression de tous les conteneurs et volumes associés
IP_RESEAU_INTERNE="192.168.56.0/24"
IP_SERVEUR="192.168.56.10"
IP_CLIENT="192.168.56.11"
IP_KALI="192.168.56.12"
IP_ROUTEUR="192.168.56.254"

# Configuration des noms d'hôtes
HOST_SERVEUR="srvssh"
HOST_CLIENT="clissh"
HOST_KALI="kali"
HOST_ROUTEUR="routeur"

# Configuration du domaine
DOMAINE=local.sio.fr

# Configuration de l'utilisateur
USERNAME="etusio"
USERPASS="Fghijkl1234*"

# Configuration des volumes
# Les volumes persistent les données du répertoire personnel
VOL_SERVEUR="home_serveur_lab1"
VOL_CLIENT="home_client_lab1"
VOL_KALI="home_kali_lab1"
VOL_ROUTEUR="home_routeur_lab1"

# ID docker HUB
ID_DOCKER=reseaucerta

# Nom de l'image
IMAGE_SERVEUR="$ID_DOCKER/serveurdebian12:lab1"
IMAGE_CLIENT="$ID_DOCKER/clientdebian12:lab1"
IMAGE_KALI="$ID_DOCKER/kalirolling:lab1"
IMAGE_ROUTEUR="$ID_DOCKER/routeurdebian12:lab1"
IMAGE_BASE=$ID_DOCKER/basedebian12:1.0

# Nom du conteneur
SERVEUR="serveur-lab1"
CLIENT="client-lab1"
KALI="kali-lab1"
ROUTEUR="routeur-lab1"

# #############################
# Définition des options
# #############################

SHOW_USAGE() {
    echo -e "\nCe script permet de créer, lancer, redémarrer, stopper, supprimer le laboratoire mais aussi de personnaliser les images."
    echo -e "Une option -c ou -l ou -d ou -s ou -r ou -i <type de l'image> ou -h doit obligatoirement être passée en ligne de commande (voir Usage ci-après)."
    echo -e "Usage: bash $0 -c|-l|d|s|r|i <type de l'image>|h"
    echo -e "\t-c\t\tCrée le laboratoire. Ce dernier sera lancé à l'issue de la création. "
    echo -e "\t-l\t\tLance un laboratoire préalablement stoppé."
    echo -e "\t-d\t\tSupprime le laboratoire. Les images et les volumes sont également supprimés."
    echo -e "\t-s\t\tStoppe le laboratoire."
    echo -e "\t-r\t\tRedémarre un laboratoire actif."
    echo -e "\t-i\t\tCrée une image personnalisée (mettre le type de l'image en majuscule) -i ROUTEUR|SERVEUR|CLIENT|KALI|BASE."
    echo -e "\t-h\t\tDétail des options."
}

# Initialisation de l'option passée au script
while getopts "cldsri:h" option; do
    # -c Crée le laboratoire.
    # -l Lance le laboratoire.
    # -d Supprime le laboratoire, les images et les volumes sont également supprimés.
    # -s Stoppe le laboratoire.
    # -r Redémarre le laboratoire.
    # -i Type de l'image en majuscule  -i ROUTEUR|SERVEUR|CLIENT|KALI|BASE."
    # -h Détail des options.

    case $option in
    c)
        if [[ -n "$launch" || -n "$delete" || -n "$stop" || -n "$restart" || -n "$type_image_o" ]]; then
            echo -e "\nUne seule option peut être passée au script."
            SHOW_USAGE
            exit 1
        fi
        create="true"
        ;;
    l)
        if [[ -n "$create" || -n "$delete" || -n "$stop" || -n "$restart" || -n "$type_image_o" ]]; then
            echo -e "\nUne seule option peut être passée au script."
            SHOW_USAGE
            exit 1
        fi
        launch="true"
        ;;

    d)
        if [[ -n "$create" || -n "$launch" || -n "$stop" || -n "$restart" || -n "$type_image_o" ]]; then
            echo -e "\nUne seule option peut être passée au script."
            SHOW_USAGE
            exit 1
        fi
        delete="true"
        ;;
    s)
        if [[ -n "$create" || -n "$launch" || -n "$delete" || -n "$restart" || -n "$type_image_o" ]]; then
            echo -e "\nUne seule option peut être passée au script."
            SHOW_USAGE
            exit 1
        fi
        stop="true"
        ;;
    r)
        if [[ -n "$create" || -n "$launch" || -n "$delete" || -n "$stop" || -n "$type_image_o" ]]; then
            echo -e "\nUne seule option peut être passée au script."
            SHOW_USAGE
            exit 1
        fi
        restart="true"
        ;;
    i)
        if [[ -n "$create" || -n "$launch" || -n "$delete" || -n "$stop" || -n "$restart" ]]; then
            echo -e "\nUne seule option peut être passée au script."
            SHOW_USAGE
            exit 1
        fi
        type_image_o="$OPTARG"
        ;;
    h)
        SHOW_USAGE
        exit
        ;;
    \?)
        echo -e "\n$COLSTOP $OPTARG : option invalide.$COLCMD\n"
        echo -e "\n$COLSTOP $OPTARG : option invalide.$COLCMD\n" >>"$LOGFILE"
        SHOW_USAGE
        exit 1
        ;;
    esac
done

if [[ -z "$create" && -z "$launch" && -z "$delete" && -z "$stop" && -z "$restart" && -z "$type_image_o" ]]; then
    echo -e "\nUne option doit obligatoirement être passée au script."
    SHOW_USAGE
    exit 1
fi

# ##################################
# Définition des fonctions
# ##################################

# Modification de la passerelle par défaut
# Qui doit être (sauf pour le routeur), l'adresse IP du routeur
MODIF_PASSERELLE() {
    NOM_CONTENEUR=$1
    docker exec --privileged "$NOM_CONTENEUR" ip route del default
    docker exec --privileged "$NOM_CONTENEUR" ip route add default via "$IP_ROUTEUR"
}

# Modification des passerelles une fois tous les conteneurs créés
MODIF_PASSERELLE_CONTENEURS() {
    # On attend 5 secondes que le processus de démarrage du dernier conteneur soit complètement terminé
    sleep 5
    echo -e "\nModification des passerelles du serveur, de Kali et du client."
    MODIF_PASSERELLE "$SERVEUR"
    MODIF_PASSERELLE "$CLIENT"
    MODIF_PASSERELLE "$KALI"
}

# Configuration des réseaux du routeur, du nat et des règles iptables
CONFIGURATION_ROUTEUR() {
    echo -e "\nConfiguration du routeur."
    # Ajout de l'interface connectée au réseau interne - eth1
    if ! (docker network inspect $NOM_RESEAU_INTERNE | grep $ROUTEUR >/dev/null); then
        docker network connect $NOM_RESEAU_INTERNE --ip "$IP_ROUTEUR" "$ROUTEUR"
        echo -e "Ajout de l'interface connectée au réseau interne... Fait"
    else
        echo -e "Interface connectée au réseau interne... Présente"

    fi

    # Activation du NAT sur le réseau connecté à l'infrastructure du BTS SIO
    if ! (docker exec --privileged "$ROUTEUR" iptables -t nat -L | grep MASQUERADE >/dev/null); then
        docker exec --privileged "$ROUTEUR" iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
        echo -e "Activation du NAT... Fait"
    else
        echo -e "NAT... Déjà activé"

    fi

    # Ajout des règles Iptables pour rediriger vers les conteneurs
    if ! (docker exec --privileged "$ROUTEUR" iptables -t nat -L | grep dpt:"$SSH_PORT_SERVEUR" >/dev/null); then
        docker exec --privileged "$ROUTEUR" iptables -t nat -A PREROUTING -p tcp --dport "$SSH_PORT_SERVEUR" -j DNAT --to-destination "$IP_SERVEUR":22
        echo -e "Ajout de la redirection SSH du serveur... Fait"
    else
        echo -e "Redirection SSH du serveur... Présente"
    fi

    if ! (docker exec --privileged "$ROUTEUR" iptables -t nat -L | grep dpt:"$SSH_PORT_CLIENT" >/dev/null); then
        docker exec --privileged "$ROUTEUR" iptables -t nat -A PREROUTING -p tcp --dport "$SSH_PORT_CLIENT" -j DNAT --to-destination "$IP_CLIENT":22
        echo -e "Ajout de la redirection SSH du client... Fait"
    else
        echo -e "Redirection SSH du client... Présente"
    fi

    if ! (docker exec --privileged "$ROUTEUR" iptables -t nat -L | grep dpt:"$SSH_PORT_KALI" >/dev/null); then
        docker exec --privileged "$ROUTEUR" iptables -t nat -A PREROUTING -p tcp --dport "$SSH_PORT_KALI" -j DNAT --to-destination "$IP_KALI":22
        echo -e "Ajout de la redirection SSH de Kali... Fait"
    else
        echo -e "Redirection SSH de Kali... Présente"
    fi

    if ! (docker exec --privileged "$ROUTEUR" iptables -t nat -L | grep dpt:"$RDP_PORT_CLIENT" >/dev/null); then
        docker exec --privileged "$ROUTEUR" iptables -t nat -A PREROUTING -p tcp --dport "$RDP_PORT_CLIENT" -j DNAT --to-destination "$IP_CLIENT":3389
        echo -e "Ajout de la redirection RDP (bureau à distance) du client... Fait"
    else
        echo -e "Redirection RDP (bureau à distance) du client... Présente"
    fi

    if ! (docker exec --privileged "$ROUTEUR" iptables -t nat -L | grep dpt:"$RDP_PORT_KALI" >/dev/null); then
        docker exec --privileged "$ROUTEUR" iptables -t nat -A PREROUTING -p tcp --dport "$RDP_PORT_KALI" -j DNAT --to-destination "$IP_KALI":3389
        echo -e "Ajout de la redirection RDP (bureau à distance) de Kali... Fait"
    else
        echo -e "Redirection RDP (bureau à distance) de Kali... Présente"
    fi
}

# ##################################
# Création du laboratoire
# ##################################

# Si des éléments du laboratoire existent, ils seront supprimés
# Sauf le réseau si la même IP est utilisée

if [ -n "$create" ]; then

    echo -e "\nCréation du laboratoire\n"

    # Création du réseau interne du LAB
    echo -e "\nCréation du réseau $IP_RESEAU_INTERNE pour le lab"
    if (docker network ls | grep $NOM_RESEAU_INTERNE >/dev/null); then
        NET_ACTUEL=$(docker network inspect --format='{{range .IPAM.Config}}{{.Subnet}}{{end}}' $NOM_RESEAU_INTERNE)
        if [ "$IP_RESEAU_INTERNE" ] && [ "$NET_ACTUEL" != "$IP_RESEAU_INTERNE" ]; then
            # shellcheck disable=SC2046
            docker rm -f $(docker ps -aq)
            # shellcheck disable=SC2046
            docker volume rm $(docker volume ls -qf dangling=true)
            docker network rm $NOM_RESEAU_INTERNE
            docker network create \
                --driver=bridge \
                --subnet="$IP_RESEAU_INTERNE" \
                "$NOM_RESEAU_INTERNE"
        else
            echo -e "Réseau $IP_RESEAU_INTERNE pour le lab... Déjà créé."
        fi
    else
        docker network create \
            --driver=bridge \
            --subnet="$IP_RESEAU_INTERNE" \
            "$NOM_RESEAU_INTERNE"
    fi

    # Lancement des conteneurs après les avoir supprimés s'ils existent
    # L'option -t permet d'attribuer un pseudo-TTY (elle n'est pas obligatoire)
    # Cela donne des logs codés par couleur que l'on peut consulter avec docker logs
    # Systemd est obligatoire pour les labos et au niveau sécurité ce n'est pas terrible
    # Pour le montage de /sys/fs/cgroup, ça ne fonctionne pas en ro...
    # Voir discussion ici : https://serverfault.com/questions/1053187/systemd-fails-to-run-in-a-docker-container-when-using-cgroupv2-cgroupns-priva

    # --privileged pour les conteneurs (obligatoire pour ROUTEUR et KALI pour la commande sysctl)
    # --cap-add NET_ADMIN permet la commande iptables et ip neigh flush (mais pas sysctl)
    # Elle devrait normalement suffire pour SERVEUR et CLIENT mais on est dans le cadre d'un labo
    # On sera peut-êre amené à passer d'autres commandes sur ces machines...

    # --pull always récupère une nouvelle image si elle existe avant de lancer le conteneur

    # Pour pouvoir accéder de l'extérieur de l'hôte aux serveurs SSH et RDP, la configuration des redirections
    # a été réalisé au niveau du routeur

    echo -e "\nCréation des conteneurs (après avoir supprimé les éventuels conteneurs existants)."
    # Suppression éventuelle des conteneurs (sans suppression des volumes)
    for conteneur in "$ROUTEUR" "$KALI" "$SERVEUR" "$CLIENT"; do
        if (docker ps -a | grep "$conteneur" >/dev/null); then
            docker rm -f "$conteneur"
            echo -e "Conteneur $conteneur existant... Supprimé."
        fi
    done

    echo -e "\nLancement du routeur"
    # Lancement du routeur
    # Le routeur est connecté au réseau de l'infrastructure du BTS SIO - eth0 (réseau bridge par défaut de Docker)
    # Adresse IP en DHCP
    if (docker run --name "$ROUTEUR" \
        --pull always \
        --network "bridge" \
        --hostname "$HOST_ROUTEUR" \
        --dns "$IP_SERVEUR" \
        --dns-search "$DOMAINE" \
        -p "$SSH_PORT_ROUTEUR":22 \
        -p "$SSH_PORT_SERVEUR":"$SSH_PORT_SERVEUR" \
        -p "$SSH_PORT_CLIENT":"$SSH_PORT_CLIENT" \
        -p "$SSH_PORT_KALI":"$SSH_PORT_KALI" \
        -p "$RDP_PORT_CLIENT":"$RDP_PORT_CLIENT" \
        -p "$RDP_PORT_KALI":"$RDP_PORT_KALI" \
        -t \
        -d \
        --tmpfs /tmp \
        --tmpfs /run \
        --tmpfs /run/lock \
        --cgroupns host \
        --privileged \
        --sysctl net.ipv4.ip_forward=1 \
        -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
        -v "$VOL_ROUTEUR":/home/"$USERNAME" \
        "$IMAGE_ROUTEUR"); then
        echo -e "conteneur $ROUTEUR... Créé"

    else
        echo -e "conteneur $ROUTEUR... Echec"
        exit 1
    fi

    echo -e "\nLancement du serveur"
    # Lancement du serveur
    if (docker run --name "$SERVEUR" \
        --pull always \
        --network "$NOM_RESEAU_INTERNE" \
        --ip "$IP_SERVEUR" \
        --hostname "$HOST_SERVEUR" \
        --dns "$IP_SERVEUR" \
        --dns-search "$DOMAINE" \
        -t \
        -d \
        --tmpfs /tmp \
        --tmpfs /run \
        --tmpfs /run/lock \
        --cgroupns host \
        --privileged \
        -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
        -v "$VOL_SERVEUR":/home/"$USERNAME" \
        "$IMAGE_SERVEUR"); then
        echo -e "conteneur $SERVEUR... Créé"

    else
        echo -e "conteneur $SERVEUR... Echec"
        exit 1
    fi

    echo -e "\nLancement du client"
    # Lancement du client
    if (docker run --name "$CLIENT" \
        --pull always \
        --network "$NOM_RESEAU_INTERNE" \
        --ip "$IP_CLIENT" \
        --hostname "$HOST_CLIENT" \
        --dns "$IP_SERVEUR" \
        --dns-search "$DOMAINE" \
        -t \
        -d \
        --tmpfs /tmp \
        --tmpfs /run \
        --tmpfs /run/lock \
        --cgroupns host \
        --privileged \
        -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
        -v "$VOL_CLIENT":/home/"$USERNAME" \
        "$IMAGE_CLIENT"); then
        echo -e "conteneur $CLIENT... Créé"

    else
        echo -e "conteneur $CLIENT... Echec"
        exit 1
    fi

    echo -e "\nLancement de Kali"
    # Lancement de Kali
    if (docker run --name "$KALI" \
        --pull always \
        --network "$NOM_RESEAU_INTERNE" \
        --ip "$IP_KALI" \
        --hostname "$HOST_KALI" \
        --dns "$IP_SERVEUR" \
        --dns-search "$DOMAINE" \
        -t \
        -d \
        --tmpfs /tmp \
        --tmpfs /run \
        --tmpfs /run/lock \
        --cgroupns host \
        --privileged \
        -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
        -v "$VOL_KALI":/home/"$USERNAME" \
        "$IMAGE_KALI"); then
        echo -e "conteneur $KALI... Créé"

    else
        echo -e "conteneur $KALI... Echec"
        exit 1
    fi

    # Modification des passerelles
    MODIF_PASSERELLE_CONTENEURS

    # Ajout des règles spécifiques pour le routeur
    CONFIGURATION_ROUTEUR

fi

# ##################################
# Lancement du laboratoire
# ##################################

if [ -n "$launch" ]; then
    echo -e "\nDémarrage des conteneurs\n"
    for conteneur in "$ROUTEUR" "$KALI" "$SERVEUR" "$CLIENT"; do
        if (docker ps -a | grep "$conteneur" >/dev/null); then
            docker start "$conteneur"
            echo -e "Conteneur $conteneur... Démarré."
        fi
    done

    # Modification éventuelle des passerelles
    MODIF_PASSERELLE_CONTENEURS

    # Ajout éventuel des règles spécifiques pour le routeur
    CONFIGURATION_ROUTEUR

fi

# ##################################
# Suppression du laboratoire
# ##################################

if [ -n "$delete" ]; then

    echo -e "\nSuppression du laboratoire\n"

    # Suppression des conteneurs
    echo -e "\nSuppression des conteneurs"
    for conteneur in "$ROUTEUR" "$KALI" "$SERVEUR" "$CLIENT"; do
        if (docker ps -a | grep "$conteneur" >/dev/null); then
            docker rm -f "$conteneur"
            echo -e "Conteneur $conteneur... Supprimé."
        fi
    done

    # Suppression du réseau
    echo -e "\nSuppression du réseau $IP_RESEAU_INTERNE"
    if (docker network ls | grep $NOM_RESEAU_INTERNE >/dev/null); then
        docker network rm $NOM_RESEAU_INTERNE
    else
        echo -e "Réseau $IP_RESEAU_INTERNE... Déjà supprimé."
    fi

    # Suppresion des volumes
    echo -e "\nSuppression des volumes"
    # shellcheck disable=SC2046
    docker volume rm $(docker volume ls --format "{{.Name}}")

    # Suppression des images
    echo -e "\nSuppression des images"
    for image in $(docker images --format "{{.Repository}}:{{.Tag}}" | grep "lab1"); do
        docker rmi "$image"
    done
    docker rmi "$ID_DOCKER"/basedebian12:1.0
    if [ "$(docker images -qf dangling=true)" ]; then
        # shellcheck disable=SC2046
        docker rmi $(docker images -qf dangling=true)
    fi
fi

# ##################################
# Arrêt du laboratoire
# ##################################

if [ -n "$stop" ]; then

    echo -e "\nArrêt des conteneurs actifs\n"
    for conteneur in "$ROUTEUR" "$KALI" "$SERVEUR" "$CLIENT"; do
        if (docker ps | grep "$conteneur" >/dev/null); then
            docker stop "$conteneur"
            echo -e "Conteneur $conteneur... Arrếté."
        fi
    done
fi

# ##################################
# Arrêt et lancement du laboratoire
# ##################################

if [ -n "$restart" ]; then

    echo -e "\nRedémarrage des conteneurs\n"
    for conteneur in "$ROUTEUR" "$KALI" "$SERVEUR" "$CLIENT"; do
        if (docker ps -a | grep "$conteneur" >/dev/null); then
            docker restart "$conteneur"
            echo -e "Conteneur $conteneur... Redémarré."
        fi
    done

    # Modification éventuelle des passerelles
    MODIF_PASSERELLE_CONTENEURS

    # Ajout éventuel des règles spécifiques pour le routeur
    CONFIGURATION_ROUTEUR

fi

# #############################
# Création des images
# #############################

if [ -n "$type_image_o" ] && ! [[ -n "$launch" || -n "$delete" || -n "$stop" || -n "$restart" ]]; then

    if [[ "$type_image_o" = "ROUTEUR" || "$type_image_o" = "SERVEUR" || "$type_image_o" = "CLIENT" || "$type_image_o" = "KALI" || "$type_image_o" = "BASE" ]]; then
        VARIABLE_IMAGE=IMAGE_$type_image_o
        eval "IMAGE=\$$VARIABLE_IMAGE"
        echo "Image est $IMAGE"
        DOCKERFILE=dockerfile_$type_image_o
        echo "Dockerfile à utiliser est $DOCKERFILE"
        if [ "$type_image_o" = "BASE" ]; then
            docker image build -t "$IMAGE" . \
                --build-arg USERNAME="$USERNAME" \
                --build-arg USERPASS="$USERPASS" \
                --file "$DOCKERFILE"
        elif [ "$type_image_o" = "KALI" ]; then
            docker image build -t "$IMAGE" . \
                --build-arg KALI_PKG="$KALI_PKG" \
                --build-arg USERNAME="$USERNAME" \
                --build-arg USERPASS="$USERPASS" \
                --file "$DOCKERFILE"
        else
            docker image build -t "$IMAGE" . \
                --build-arg IMAGE_BASE="$IMAGE_BASE" \
                --build-arg USERNAME="$USERNAME" \
                --build-arg USERPASS="$USERPASS" \
                --file "$DOCKERFILE"
        fi
    else
        echo -e "Le type de l'image passé en option ne peut être que ROUTEUR, SERVEUR, CLIENT, KALI ou BASE en majuscule"
    fi

fi
