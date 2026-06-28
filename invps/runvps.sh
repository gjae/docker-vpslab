# 1. Obtener el GID numérico del cliente en Virtualmin (ej. puede ser 1005)
GID_CLIENTE=$(id -g jessec)

# 2. Crear un volumen Docker dedicado a las configuraciones del sistema de este cliente
docker volume create config_jessec

# 3. Lanzar el contenedor con el puerto SSH dedicado y el volumen de persistencia
docker run -d \
  --name contenedor_jessec \
  --restart always \
  --memory="5g" \
  --cpus="1.0" \
  -p 2201:22 \
  -v config_jessec:/etc \
  -v /home/jessec/public_html:/var/www/html \
  ubuntu-hosting-ssh
