#!/bin/bash
# shellcheck disable=SC2181,SC2001
# shellcheck source=/dev/null

# Import du fichier des variables
# Du moment que les images sont disponibles sur le docker hub
# Recopier éventuellement ici les variables pour ne donner aux étudiants que ce script
source ./variables

# Création du réseau
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

# Supprimer --security-opt seccomp=unconfined \ si le noyau ne le supporte pas
# --privileged pour ROUTEUR et KALI sinon pas do commande sysctl possible à l'intérieur du conteneur
# --cap-add NET_ADMIN permet la commande iptables au sein du conteneur mais pas sysctl...

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
    --network "$NOM_RESEAU" \
    --ip "$IP_ROUTEUR" \
    --hostname "$HOST_ROUTEUR" \
    --dns "$IP_SERVEUR" \
    --dns-search "$DOMAINE" \
    -p "$SSH_PORT_ROUTEUR":22 \
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

# Activation du NAT
docker exec --privileged "$ROUTEUR" iptables -t nat -A POSTROUTING -s "$IP_RESEAU" -o eth0 -j MASQUERADE

echo -e "Lancement et configuration du serveur"
# Lancement du serveur
docker run --name "$SERVEUR" \
    --network "$NOM_RESEAU" \
    --ip "$IP_SERVEUR" \
    --hostname "$HOST_SERVEUR" \
    --dns "$IP_SERVEUR" \
    --dns-search "$DOMAINE" \
    -p "$SSH_PORT_SERVEUR":22 \
    -t \
    -d \
    --tmpfs /tmp \
    --tmpfs /run \
    --tmpfs /run/lock \
    --cgroupns host \
    --security-opt seccomp=unconfined \
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
    -p "$RDP_PORT_CLIENT":3389 \
    -p "$SSH_PORT_CLIENT":22 \
    -t \
    -d \
    --tmpfs /tmp \
    --tmpfs /run \
    --tmpfs /run/lock \
    --cgroupns host \
    --security-opt seccomp=unconfined \
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
    -p "$RDP_PORT_KALI":3389 \
    -p "$SSH_PORT_KALI":22 \
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
