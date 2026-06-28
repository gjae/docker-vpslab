#!/bin/bash

# Verificar que el script se ejecuta con privilegios de superusuario en el host principal
if [ "$EUID" -ne 0 ]; then
  echo "Error: Este script debe ejecutarse como root."
  exit 1
fi

# Validar argumentos obligatorios
if [ "$#" -lt 3 ]; then
    echo "===================================================================================================="
    echo "Uso: $0 <usuario_virtualmin> <puerto_ssh_cliente> <password_root_interno> [memoria] [cpus] [disco]"
    echo "Ejemplo: $0 cliente1 2201 MiPasswordSeguro123 4g 1.5 5G"
    echo "===================================================================================================="
    exit 1
fi

# Captura de variables
USUARIO_HOST=$1
PUERTO_SSH=$2
PASSWORD_ROOT=$3
MEMORIA=${4:-"2g"}
CPUS=${5:-"1.0"}
ALMACENAMIENTO=${6:-"5G"} # Nuevo parámetro dinámico (por defecto 5 Gigabytes)

CONTENEDOR="contenedor_${USUARIO_HOST}"
RUTA_HOME="/home/${USUARIO_HOST}/public_html"
IMAGEN_DOCKER="ubuntu-hosting-root-ssh"

echo "--------------------------------------------------------"
echo "Iniciando aprovisionamiento Micro-VPS para: $USUARIO_HOST"
echo "--------------------------------------------------------"

# 1. Verificar la preexistencia del directorio asignado por Virtualmin
if [ ! -d "$RUTA_HOME" ]; then
    echo "Error: La ruta web $RUTA_HOME no existe en el sistema anfitrión."
    echo "Por favor, crea el servidor virtual en Virtualmin previamente."
    exit 1
fi

# 2. Construir la imagen de Docker con acceso Root SSH permitido (Solo si no existe)
if ! docker images --format "{{.Repository}}" | grep -q "^${IMAGEN_DOCKER}$"; then
    echo "[+] Construyendo imagen base de Ubuntu con SSH para acceso Root..."
    
    cat << 'EOF' > /tmp/DockerfileRoot
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y openssh-server vim curl && mkdir /var/run/sshd
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

# 4. Desplegar el contenedor con mapeo de puertos, volúmenes y límite de DISCO
echo "[+] Desplegando el Micro-VPS aislado..."
docker volume create "config_${USUARIO_HOST}" >/dev/null

docker run -d \
  --name "$CONTENEDOR" \
  --restart always \
  --memory="$MEMORIA" \
  --cpus="$CPUS" \
  --storage-opt size="$ALMACENAMIENTO" \
  -p "${PUERTO_SSH}:22" \
  -v "config_${USUARIO_HOST}:/etc" \
  -v "${RUTA_HOME}:/var/www/html" \
  "$IMAGEN_DOCKER" >/dev/null

sleep 3 # Esperar arranque del servicio SSH interno

# 5. Configurar la contraseña y persistencia del SSH interno
echo "[+] Inyectando credenciales y reiniciando SSH interno..."
docker exec -i "$CONTENEDOR" bash -c "sed -i 's/.*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config"
docker exec -i "$CONTENEDOR" bash -c "sed -i 's/.*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config"

# Inyectar la contraseña usando chpasswd
docker exec -i "$CONTENEDOR" bash -c "echo 'root:${PASSWORD_ROOT}' | chpasswd"
docker exec -i "$CONTENEDOR" service ssh restart >/dev/null

# 6. Prevenir Errores 403 (SetGID en la carpeta del host)
echo "[+] Sincronizando permisos compartidos con Virtualmin..."
chown -R ${USUARIO_HOST}:${USUARIO_HOST} "$RUTA_HOME"
chmod -R 2775 "$RUTA_HOME"

echo "=================================================================="
echo " ¡Aprovisionamiento del Entorno Aislado completado con éxito! "
echo "=================================================================="
echo " Cliente / Web : $USUARIO_HOST"
echo " Contenedor    : $CONTENEDOR"
echo " Recursos      : RAM: $MEMORIA | CPU: $CPUS | Disco Interno: $ALMACENAMIENTO"
echo ""
echo " -> ACCESO PARA EL CLIENTE:"
echo "    Comando    : ssh root@<IP_DE_TU_SERVIDOR> -p $PUERTO_SSH"
echo "=================================================================="
