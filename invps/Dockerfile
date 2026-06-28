FROM ubuntu:24.04

# Actualizar e instalar OpenSSH y utilidades
RUN apt-get update && apt-get install -y openssh-server sudo vim && \
    mkdir /var/run/sshd

# (Opcional) Configurar para que no permita login del root interno por SSH
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config

# Exponer el puerto SSH interno
EXPOSE 22

# Mantener el servicio SSH corriendo en primer plano
CMD ["/usr/sbin/sshd", "-D"]
