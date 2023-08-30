#!/bin/bash
# shellcheck disable=SC2181,SC2001
# shellcheck source=/dev/null

# Du moment que les images sont disponibles sur le docker hub
# Recopier éventuellement ici les variables pour ne donner aux étudiants que ce script
# Ou si vous n'avez pas modifié les variables, décommenter les deux lignes suivantes :
# cp variables variables.old
# wget https://forge.aeif.fr/btssio-labos-kali/lab1/-/raw/main/variables --output-document variables

# Import du fichier des variables
source variables

# Création du réseau interne du LAB
echo -e "\nCréation du réseau $IP_RESEAU pour le lab"
if (docker network ls | grep bridge_lab1 >/dev/null); then
    NET_ACTUEL=$(docker network inspect --format='{{range .IPAM.Config}}{{.Subnet}}{{end}}' bridge_lab1)
    if [ "$IP_RESEAU" ] && [ "$NET_ACTUEL" != "$IP_RESEAU" ]; then
        # shellcheck disable=SC2046
        docker rm -f $(docker ps -aq)
        # shellcheck disable=SC2046
        docker volume rm $(docker volume ls -qf dangling=true)
        docker network rm bridge_lab1
        docker network create \
            --driver=bridge \
            --subnet="$IP_RESEAU" \
            "$NOM_RESEAU"
    else
        echo -e "Réseau $IP_RESEAU pour le lab... Déjà créé."
    fi
else
    docker network create \
        --driver=bridge \
        --subnet="$IP_RESEAU" \
        "$NOM_RESEAU"
fi

# Fonction qui modifie la passerelle par défaut
# Qui doit être (sauf pour le routeur), l'adresse IP du routeur
MODIF_PASSERELLE() {
    NOM_CONTENEUR=$1
    docker exec --privileged "$NOM_CONTENEUR" ip route del default
    docker exec --privileged "$NOM_CONTENEUR" ip route add default via "$IP_ROUTEUR"
}

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

echo -e "Lancement et configuration du routeur"
# Lancement du routeur
docker run --name "$ROUTEUR" \
    --pull always \
    --network "$NOM_RESEAU" \
    --ip "$IP_ROUTEUR" \
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
    "$IMAGE_ROUTEUR"

# Ajout de la carte connecté au réseau de la section (réseau bridge par défaut de Docker)
docker network connect bridge "$ROUTEUR"

# Activation du NAT sur cette carte
docker exec --privileged "$ROUTEUR" iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE

# Ajout des règles Iptables pour rediriger vers les conteneurs
docker exec --privileged "$ROUTEUR" iptables -t nat -A PREROUTING -p tcp --dport "$SSH_PORT_SERVEUR" -j DNAT --to-destination "$IP_SERVEUR":22
docker exec --privileged "$ROUTEUR" iptables -t nat -A PREROUTING -p tcp --dport "$SSH_PORT_CLIENT" -j DNAT --to-destination "$IP_CLIENT":22
docker exec --privileged "$ROUTEUR" iptables -t nat -A PREROUTING -p tcp --dport "$SSH_PORT_KALI" -j DNAT --to-destination "$IP_KALI":22
docker exec --privileged "$ROUTEUR" iptables -t nat -A PREROUTING -p tcp --dport "$RDP_PORT_CLIENT" -j DNAT --to-destination "$IP_CLIENT":3389
docker exec --privileged "$ROUTEUR" iptables -t nat -A PREROUTING -p tcp --dport "$RDP_PORT_KALI" -j DNAT --to-destination "$IP_KALI":3389

echo -e "Lancement et configuration du serveur"
# Lancement du serveur
docker run --name "$SERVEUR" \
    --network "$NOM_RESEAU" \
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
    "$IMAGE_SERVEUR"

# Modification de la passerelle par défaut
MODIF_PASSERELLE "$SERVEUR"

echo -e "Lancement et configuration du client"
# Lancement du client
docker run --name "$CLIENT" \
    --network "$NOM_RESEAU" \
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
    "$IMAGE_CLIENT"

# Modification de la passerelle par défaut
MODIF_PASSERELLE "$CLIENT"

echo -e "Lancement et configuration de Kali"
# Lancement de Kali
docker run --name "$KALI" \
    --network "$NOM_RESEAU" \
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
    "$IMAGE_KALI"

# Modification de la passerelle par défaut
MODIF_PASSERELLE "$KALI"
