# Script de Particionado Automático con `parted`

Este script en Bash automatiza la creación de particiones en discos utilizando `parted`. Ha sido diseñado para funcionar en múltiples distribuciones de Linux y maneja varias comprobaciones de seguridad y compatibilidad antes de ejecutar cualquier cambio en los discos.

---

## ⚙️ Características

- **Verificación de permisos de administrador** antes de ejecutarse.
- **Detección automática de la distribución** para usar el gestor de paquetes correcto.
- **Instalación automática de `parted`** si no está presente.
- **Verificación de conexión a Internet** antes de instalar paquetes.
- **Listado de discos disponibles sin particiones montadas**.
- **Creación de tabla de particiones GPT**.
- **Opción para crear 128 particiones o un número personalizado**.
- **Confirmación explícita del usuario antes de destruir datos**.
- **Registro detallado de la ejecución** en `partition_script.log`.

---

## 🖥️ Requisitos

- Ejecutar como **usuario root** o mediante `sudo`.
- Conexión a Internet si `parted` no está instalado.
- Espacio libre en un disco sin particiones montadas para realizar pruebas.

---

## 📦 Distribuciones compatibles

El script detecta automáticamente y usa el gestor de paquetes adecuado en las siguientes distribuciones:

| Distribución       | Gestor de paquetes usado     |
|--------------------|------------------------------|
| Debian, Ubuntu     | `apt`                        |
| Arch, Manjaro      | `pacman`                     |
| Fedora             | `dnf`                        |
| RHEL, CentOS       | `yum` o `dnf`                |
| openSUSE           | `zypper`                     |
| Alpine             | `apk`                        |
| Gentoo             | `emerge`                     |

> ⚠️ Si tu distribución no está listada, el script te notificará para realizar la instalación manual de `parted`.

---

## 🚀 Uso

```bash
sudo ./script_particionado.sh
