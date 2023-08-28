#!/bin/bash
# shellcheck disable=SC2181,SC2001
# shellcheck source=/dev/null

# Import du fichier des variables d'environnement
source ./variables

# À faire : possibilité de créer toutes les images avec une option -a

SHOW_USAGE() {
    echo -e "\nCe script permet de créer les différentes images."
    echo -e "Le type de l'image (ROUTEUR, SERVEUR, CLIENT, KALI ou BASE) doit être passé en paramètre (voir Usage ci-après)."
    echo -e "Usage: create_images_lab1.sh -i type de l'image"
    echo -e "\t-i\t\tType de l'image en majuscule  -i ROUTEUR|SERVEUR|CLIENT|KALI|BASE"
    echo -e "\t-h\t\tDétail des options."
}

# Initialisation du paramètre passé au script
while getopts "i:h" option; do
    case $option in
    i) type_image_o=$OPTARG ;;
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
