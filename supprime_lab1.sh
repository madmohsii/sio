#!/bin/bash
# shellcheck disable=SC2181,SC2001
# shellcheck source=/dev/null

# Recopier éventuellement ici les variables pour ne donner aux étudiants que ce script
# Ou si vous n'avez pas modifié les variables, décommenter les deux lignes suivantes :
# cp variables variables.old
# wget https://forge.aeif.fr/btssio-labos-kali/lab1/-/raw/main/variables --output-document variables

# Import du fichier des variables d'environnement
source variables

# suppression des conteneurs
echo -e "\nSuppression des conteneurs"
for conteneur in "$ROUTEUR" "$KALI" "$SERVEUR" "$CLIENT"; do
    if (docker ps -a | grep "$conteneur" >/dev/null); then
        docker rm -f "$conteneur"
        echo -e "Conteneur $conteneur... Supprimé."
    fi
done

# Suppression du réseau
echo -e "\nSuppression du réseau $IP_RESEAU"
if (docker network ls | grep bridge_lab1 >/dev/null); then
    docker network rm bridge_lab1
else
    echo -e "Réseau $IP_RESEAU... Déjà supprimé."
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
