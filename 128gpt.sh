#!/bin/bash

clear

bash 128GPTASCII

# Nombre del log
LOG_FILE="./partition_script.log"

# Función para escribir mensajes en el log con timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Verificar si el script se ejecuta con permisos de administrador
if [ "$EUID" -ne 0 ]; then
    echo "Este script debe ejecutarse como root o con permisos de administrador."
    exit 1
fi

log_message "Inicio del script de particionado."

# Función para instalar 'parted' según la distribución detectada
instalar_parted() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        distro=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
        log_message "Distribución detectada: $distro"
    else
        log_message "No se pudo detectar la distribución. Proceda con la instalación manual."
        exit 1
    fi

log_message "Inicio del script de particionado."

# Función para instalar 'parted' según la distribución detectada
instalar_parted() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        distro=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
        log_message "Distribución detectada: $distro"
    else
        log_message "No se pudo detectar la distribución. Proceda con la instalación manual."
        exit 1
    fi

    case "$distro" in
        ubuntu|debian|linuxmint|kali)
            apt update && apt install -y parted
            ;;
        arch|manjaro)
            pacman -S --noconfirm parted
            ;;
        fedora)
            dnf install -y parted
            ;;
        rhel|centos)
            yum install -y parted || dnf install -y parted
            ;;
        opensuse* )
            zypper install -y parted
            ;;
        alpine)
            apk add parted
            ;;
        gentoo)
            emerge --ask sys-block/parted
            ;;
        *)
            log_message "Distribución '$distro' no soportada automáticamente. Instala 'parted' manualmente."
            exit 1
            ;;
    esac

    if command -v parted &> /dev/null; then
        log_message "'parted' se instaló correctamente."
    else
        log_message "Error: No se pudo instalar 'parted'."
        exit 1
    fi
}

# Verificar si 'parted' está instalado
if ! command -v parted &> /dev/null; then
    echo "El programa 'parted' no está instalado."
    read -p "¿Quieres instalarlo? (s/n): " respuesta
    if [[ "$respuesta" =~ ^[sS]$ ]]; then
        log_message "El usuario eligió instalar 'parted'."
        echo "Verificando conexión a Internet..."
        if ping -c 1 8.8.8.8 &> /dev/null; then
            log_message "Conexión a Internet verificada."
            instalar_parted
        else
            log_message "No hay conexión a Internet. No se puede instalar 'parted'."
            echo "No hay conexión a Internet. No se puede instalar 'parted'."
            exit 1
        fi
    else
        log_message "El usuario optó por no instalar 'parted'."
        echo "No se instalará 'parted'. Cerrando el script."
        exit 1
    fi
fi

clear

bash 128GPTASCII

# Función para obtener la lista de discos sin particionar
obtener_discos_libres() {
    lsblk -dn -o NAME,SIZE,TYPE | awk '$3=="disk" {print "/dev/" $1 " - Tamaño: " $2}'
}

# Función para verificar si un disco tiene particiones o si están montadas
verificar_disco() {
    local disco="$1"
    # Verifica si el disco tiene particiones
    if lsblk "$disco" -n -o NAME,TYPE | grep -q "part"; then
        # Si tiene particiones, verificamos que no estén montadas
        if mount | grep -q "^$disco"; then
            return 1  # En uso
        fi
    fi
    return 0  # No está en uso o no tiene particiones
}

# Listar discos disponibles sin particionar (o sin particiones montadas)
log_message "Listando discos sin particionar o no en uso."
available_disks=$(for disk in $(lsblk -dn -o NAME,TYPE | awk '$2=="disk" {print $1}'); do
    full_disk="/dev/$disk"
    # Solo mostrar disco si no tiene particiones montadas
    if verificar_disco "$full_disk"; then
        size=$(lsblk -dn -o SIZE "$full_disk")
        echo "$full_disk - Tamaño: $size"
    fi
done)

if [ -z "$available_disks" ]; then
    log_message "No hay ningún disco sin particionar o disponible (sin particiones montadas)."
    echo "No hay ningún disco sin particionar disponible."
    exit 1
fi

echo "Discos disponibles sin particionar o sin particiones montadas:"
echo "$available_disks"

# Seleccionar disco
read -p "Introduce el disco que quieres particionar (ej. /dev/sdx): " disco_seleccionado

# Validar que el disco seleccionado está en la lista de discos disponibles
if ! echo "$available_disks" | grep -q "$disco_seleccionado"; then
    log_message "El disco introducido ($disco_seleccionado) no se encuentra en la lista de discos disponibles."
    echo "El disco introducido no es válido o no está disponible para particionar."
    exit 1
fi

if [ -e "$disco_seleccionado" ]; then
    log_message "El disco $disco_seleccionado existe."
    DISK="$disco_seleccionado"
else
    log_message "El disco $disco_seleccionado no existe."
    echo "El disco $disco_seleccionado no existe."
    exit 1
fi

# Advertencia final y confirmación de que se destruirán los datos
echo "¡ATENCIÓN! Se procederá a crear una tabla de particiones GPT en $DISK, lo que borrará TODOS los datos existentes en ese disco>
read -p "¿Estás seguro de que deseas continuar? (s/n): " confirmacion
if [[ ! "$confirmacion" =~ ^[sS]$ ]]; then
    log_message "El usuario canceló la operación después de la advertencia."
    echo "Operación cancelada. Cerrando el script."
    exit 1
fi

log_message "El usuario confirmó la operación en $DISK."

# Crear tabla de particiones GPT
log_message "Creando tabla de particiones GPT en $DISK."
parted -s "$DISK" mklabel gpt
if [ $? -ne 0 ]; then
    log_message "Error al crear la tabla de particiones en $DISK."
    echo "Error al crear la tabla de particiones."
    exit 1
fi

clear

bash 128GPTASCII

# Menú de opciones para el número de particiones a crear
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
            log_message "Número de particiones ingresado no es válido."
            echo "Número inválido."
            exit 1
        fi
        ;;
    3)
        log_message "El usuario canceló la operación en el menú de particionado."
        echo "Saliendo del script."
        exit 0
        ;;
    *)
        log_message "Opción inválida en el menú."
        echo "Opción inválida."
        exit 1
        ;;
esac

# Crear particiones según la opción elegida
log_message "Creando $part particiones en $DISK."
for i in $(seq 1 $part); do
    start=$((i * 5))
    end=$((i * 5 + 4))
    parted -s "$DISK" mkpart primary "${start}MiB" "${end}MiB"
    if [ $? -eq 0 ]; then
        log_message "Partición $i creada en $DISK: ${start}MiB - ${end}MiB."
        echo "Partición $i creada en $DISK."
    else
        log_message "Error al crear la partición $i en $DISK."
        echo "Error al crear la partición $i."
        exit 1
    fi
done

# Mostrar tabla de particiones
echo "Tabla de particiones de $DISK:"
parted -s "$DISK" print
log_message "Operación completada en $DISK."

exit 0
