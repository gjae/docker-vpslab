# Docker VPSLab 🚀

**Infraestructura de Hosting Aislado basada en la Arquitectura Micro-VPS**

Docker VPSLab es un conjunto de herramientas y scripts diseñados para resolver el problema clásico del alojamiento compartido (shared hosting). Utilizando **Docker**, **Virtualmin** y un enrutamiento **SSH dedicado**, este proyecto permite aislar de forma estricta los entornos de desarrollo de los clientes, otorgándoles privilegios de `root` interno y recursos de hardware limitados, sin comprometer la seguridad del servidor anfitrión.

## ✨ Características Principales

- 🛡️ **Aislamiento Total (Micro-VPS):** Cada cliente opera dentro de su propio contenedor con un sistema de archivos independiente.
- 🔌 **SSH Dedicado y Directo:** Acceso a través de puertos mapeados (ej. `2201`, `2202`), eliminando la necesidad de interceptar el puerto 22 del host.
- 💾 **Persistencia de Credenciales:** Los cambios de contraseñas de `root` o la creación de nuevos usuarios dentro del contenedor se guardan permanentemente mediante volúmenes de Docker.
- 🔄 **Sincronización Transparente con Virtualmin:** Implementación de permisos automáticos (`SetGID`) para evitar el temido *Error 403 Forbidden* cuando el servidor web nativo (Apache/Nginx) intenta leer los archivos del cliente.
- ⚡ **Aprovisionamiento de 1 Clic:** Script en Bash automatizado que genera la imagen, asigna recursos (CPU/RAM) y despliega el entorno en segundos.

## 📋 Requisitos Previos

Para desplegar esta arquitectura en producción, tu servidor anfitrión debe cumplir con lo siguiente:

1. **Sistema Operativo:** Ubuntu 24.04 LTS o Debian 12 (Recomendado).
2. **Panel de Control:** Virtualmin / Webmin plenamente operativo.
3. **Docker Engine:** Instalado de forma nativa (`docker-ce`, `docker-ce-cli`, `containerd.io`).
4. **VirtualHost Base:** Un servidor virtual o dominio ya creado para el cliente en Virtualmin (el directorio `/home/usuario/public_html` debe existir).

## 🚀 Instalación y Uso

1. **Clona el repositorio en tu servidor:**
   ```bash
   git clone [https://github.com/gjae/docker-vpslab.git](https://github.com/gjae/docker-vpslab.git)
   cd docker-vpslab
   sudo chmod +x scripts/provisionar-micro-vps.sh
   sudo ./provisionar-micro-vps.sh <usuario_virtualmin> <puerto_ssh> <password_root> [memoria] [cpus]
   sudo ./provisionar-micro-vps.sh cliente1 2201 ClaveSegura123 4g 1.5
```
