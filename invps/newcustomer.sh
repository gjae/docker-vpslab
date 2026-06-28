#!/bin/bash

# Verificar que el script se ejecuta con privilegios de superusuario en el host principal
if [ "$EUID" -ne 0 ]; then
  echo "Error: Este script debe ejecutarse como root."
  exit 1
fi

# Validar argumentos obligatorios
if [ "$#" -lt 3 ]; then
    echo "========================================================================================="
    echo "Uso: $0 <usuario_virtualmin> <puerto_ssh_cliente> <password_root_interno> [memoria] [cpus]"
    echo "Ejemplo: $0 jessec 2201 MiPasswordSeguro123 4g 1.0"
    echo "========================================================================================="
    exit 1
fi

# Captura de variables
USUARIO_HOST=$1
PUERTO_SSH=$2
PASSWORD_ROOT=$3
MEMORIA=${4:-"2g"}
CPUS=${5:-"1.0"}

CONTENEDOR="contenedor_${USUARIO_HOST}"
RUTA_HOME="/home/${USUARIO_HOST}/public_html"
IMAGEN_DOCKER="ubuntu-hosting-root-ssh"

echo "--------------------------------------------------------"
echo "Iniciando aprovisionamiento para el cliente: $USUARIO_HOST"
echo "--------------------------------------------------------"

# 1. Verificar la preexistencia del directorio asignado por Virtualmin
if [ ! -d "$RUTA_HOME" ]; then
    echo "Error: La ruta web $RUTA_HOME no existe en el sistema anfitrión."
    echo "Por favor, crea el servidor virtual en Virtualmin previamente."
    exit 1
fi

# 2. Construir la imagen de Docker con acceso Root SSH permitido (Solo lo hace si no existe)
if ! docker images --format "{{.Repository}}" | grep -q "^${IMAGEN_DOCKER}$"; then
    echo "[+] Construyendo imagen base de Ubuntu con SSH para acceso Root..."
    
    # Crear Dockerfile temporal
    cat << 'EOF' > /tmp/DockerfileRoot
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y openssh-server vim curl && mkdir /var/run/sshd
# Habilitar explícitamente el acceso por contraseña para root
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
EOF

    docker build -t "$IMAGEN_DOCKER" -f /tmp/DockerfileRoot /tmp/
    rm /tmp/DockerfileRoot
fi

# 3. Eliminar el contenedor previo si existe para recrearlo limpio
if docker ps -a --format '{{.Names}}' | grep -Eq "^${CONTENEDOR}$"; then
    echo "[+] El contenedor $CONTENEDOR ya existe. Deteniendo y recreando..."
    docker rm -f "$CONTENEDOR" >/dev/null
fi

# 4. Desplegar el contenedor con mapeo de puertos y volúmenes
echo "[+] Desplegando el Micro-VPS aislado..."
docker volume create "config_${USUARIO_HOST}" >/dev/null

docker run -d \
  --name "$CONTENEDOR" \
  --restart always \
  --memory="$MEMORIA" \
  --cpus="$CPUS" \
  -p "${PUERTO_SSH}:22" \
  -v "config_${USUARIO_HOST}:/etc" \
  -v "${RUTA_HOME}:/var/www/html" \
  "$IMAGEN_DOCKER" >/dev/null

# Pequeña pausa para permitir que el servicio SSH interno arranque
sleep 3

# 5. Configurar la contraseña y persistencia del SSH interno
echo "[+] Inyectando credenciales seguras y reiniciando SSH interno..."
# Forzar las directivas en el volumen persistente /etc por si acaso
docker exec -i "$CONTENEDOR" bash -c "sed -i 's/.*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config"
docker exec -i "$CONTENEDOR" bash -c "sed -i 's/.*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config"

# Inyectar la contraseña usando chpasswd sin interactividad
docker exec -i "$CONTENEDOR" bash -c "echo 'root:${PASSWORD_ROOT}' | chpasswd"

# Reiniciar el demonio SSH interno para aplicar los cambios
docker exec -i "$CONTENEDOR" service ssh restart >/dev/null

# 6. Prevenir Errores 403 (SetGID en la carpeta del host)
echo "[+] Sincronizando permisos compartidos con Virtualmin..."
chown -R ${USUARIO_HOST}:${USUARIO_HOST} "$RUTA_HOME"
chmod -R 2775 "$RUTA_HOME"

echo "=================================================================="
echo " ¡Aprovisionamiento del Entorno Aislado completado con éxito! "
echo "=================================================================="
echo " Cliente / Carpeta Web : $USUARIO_HOST"
echo " Contenedor Asignado   : $CONTENEDOR"
echo " Recursos Limitados    : RAM: $MEMORIA | CPU: $CPUS"
echo ""
echo " -> DATOS DE ACCESO PARA EL CLIENTE:"
echo "    Comando    : ssh root@<IP_DE_TU_SERVIDOR> -p $PUERTO_SSH"
echo "    Contraseña : $PASSWORD_ROOT"
echo "=================================================================="
