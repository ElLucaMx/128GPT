#!/bin/bash
# Autor: ElLucaMx
# V-4.1

clear
bash 128GPTASCII

# Nombre del log
ARCHIVO_LOG="./partition_script.log"

# Función para escribir mensajes en el log con timestamp
escribir_log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$ARCHIVO_LOG"
}

escribir_log "Inicio del script 128GPT."

# Verificar si el script se ejecuta con permisos de administrador
if [ "$EUID" -ne 0 ]; then
    echo "Este script debe ejecutarse como root o con permisos de administrador."
    exit 1
fi

# Función para instalar 'parted' y 'dialog' según la distribución detectada
instalar_dependencias() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        distro=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
        echo "Distribución detectada: $distro"
    else
        echo "No se pudo detectar la distribución. Proceda con la instalación manual."
        exit 1
    fi

    case "$distro" in
        ubuntu|debian|linuxmint|kali)
            apt update && apt install -y parted dialog
            ;;
        arch|manjaro)
            pacman -Syu --noconfirm parted dialog
            ;;
        fedora)
            dnf install -y parted dialog
            ;;
        rhel|centos)
            yum install -y parted dialog || dnf install -y parted dialog
            ;;
        opensuse*)
            zypper install -y parted dialog
            ;;
        alpine)
            apk add parted dialog
            ;;
        gentoo)
            emerge --ask sys-block/parted app-misc/dialog
            ;;
        *)
            echo "Distribución '$distro' no soportada. Instala 'parted' y 'dialog' manualmente."
            exit 1
            ;;
    esac

    if command -v parted &> /dev/null && command -v dialog &> /dev/null; then
        echo "Las dependencias se instalaron correctamente."
    else
        echo "Error: No se pudo instalar las dependencias ('parted' o 'dialog')."
        exit 1
    fi
}

# Verificar e instalar dependencias si no están presentes
verificar_instalar_programa() {
    programa=$1
    if ! command -v "$programa" &> /dev/null; then
        echo "La dependencia '$programa' no está instalada."
        read -p "¿Quieres instalarla? (s/n): " respuesta
        if [[ "$respuesta" =~ ^[sS]$ ]]; then
            instalar_dependencias
        else
            echo "No se instalará '$programa'. Cerrando el script."
            exit 1
        fi
    fi
}

verificar_instalar_programa parted
verificar_instalar_programa dialog

clear
bash 128GPTASCII
echo "Iniciando el script."
sleep 5

# Obtener lista de discos disponibles sin particiones montadas y sin RAID
filtrar_discos_sin_particiones_o_raid() {
    local discos; discos=$(lsblk -dn -o NAME,TYPE | awk '$2 == "disk" { print $1 }')
    local raids_raw; raids_raw=$(mdadm --detail --scan 2>/dev/null)
    local raids="";
    local disco;

    if [[ -n "$raids_raw" ]]; then
        raids=$(grep -oE '/dev/[a-z]+[a-z]+' <<< "$raids_raw" | grep -E '^/dev/[a-z]+$' | xargs -n1 basename)
    fi

    if [[ -z "$discos" ]]; then
        printf "No se encontraron discos físicos.\n" >&2
        return 1
    fi

    while IFS= read -r disco; do
        local tiene_particiones; tiene_particiones=$(lsblk -n -o NAME "/dev/$disco" | grep -v "^$disco$")

        if [[ -n "$tiene_particiones" ]]; then
            continue
        fi

        if [[ -n "$raids" ]] && printf "%s\n" "$raids" | grep -qw "$disco"; then
            continue
        fi

        printf "/dev/%s\n" "$disco"
    done <<< "$discos"
}

# Filtrar y obtener los discos disponibles
discos_disponibles=$(filtrar_discos_sin_particiones_o_raid)

if [ -z "$discos_disponibles" ]; then
    echo "No hay discos disponibles para particionar."
    exit 1
fi

# Crear lista de elementos para dialog: cada línea tendrá el nombre del disco y su información
IFS=$'\n'
elementos_menu=()
for linea in $discos_disponibles; do
    nombre_disco=$(echo "$linea" | awk '{print $1}')
    info_disco=$(lsblk -dn -o SIZE "$nombre_disco")
    elementos_menu+=("$nombre_disco" "$info_disco")
done

# Usar dialog para mostrar la selección de disco
exec 3>&1
disco_seleccionado=$(dialog --clear \
    --backtitle "Seleccionar Disco" \
    --title "Discos Disponibles" \
    --menu "Elige el disco que deseas particionar:" 15 60 6 \
    "${elementos_menu[@]}" \
    2>&1 1>&3)
exit_status=$?
exec 3>&-

clear

# Validar selección del disco
if [ $exit_status -ne 0 ] || [ -z "$disco_seleccionado" ]; then
    echo "No se seleccionó ningún disco. Saliendo..."
    exit 1
fi

if [ ! -e "$disco_seleccionado" ]; then
    echo "El disco $disco_seleccionado no existe."
    exit 1
fi

DISCO="$disco_seleccionado"

# Confirmación final con dialog --yesno
dialog --title "⚠️ Advertencia" \
    --yesno "¡ATENCIÓN!\n\nSe procederá a crear una tabla de particiones GPT en:\n\n  $DISCO\n\nEsto BORRARÁ TODOS los datos del disco.\n\n¿Deseas continuar?" 15 60

clear

if [ $? -ne 0 ]; then
    clear
    echo "Operación cancelada. Cerrando el script."
    exit 1
fi

# Crear tabla de particiones GPT
parted -s "$DISCO" mklabel gpt
if [ $? -ne 0 ]; then
    echo "Error al crear la tabla de particiones."
    exit 1
fi

clear
bash 128GPTASCII

# Selección del número de particiones
echo "Seleccione una opción:"
echo "1) Crear 128 particiones."
echo "2) Crear un número personalizado de particiones."
echo "3) Cancelar y salir."
read -p "Opción: " opcion

case $opcion in
    1)
        part=128
        ;;
    2)
        read -p "Ingrese el número de particiones a crear: " part
        if ! [[ $part =~ ^[0-9]+$ ]]; then
            echo "Número inválido."
            exit 1
        fi
        ;;
    3)
        echo "Saliendo del script."
        exit 0
        ;;
    *)
        echo "Opción inválida."
        exit 1
        ;;
esac

# Crear particiones en el disco seleccionado
for i in $(seq 1 $part); do
    start=$((i * 5))
    end=$((i * 5 + 4))
    parted -s "$DISCO" mkpart primary "${start}MiB" "${end}MiB"
    if [ $? -eq 0 ]; then
        echo "Partición $i creada en $DISCO."
    else
        echo "Error al crear la partición $i."
        exit 1
    fi
done

echo "Tabla de particiones de $DISCO:"
parted -s "$DISCO" print

exit 0
