#!/bin/sh
# Script de instalación de Tryton con PostgreSQL en FreeBSD 15
# Versión COMPLETA - Incluye SAO, npm, CA interna (ECDSA) y 4 servicios independientes

# Colores para output (compatibles con printf en FreeBSD)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Funciones de control
postgres_act() {
    if /usr/local/etc/rc.d/postgresql status >/dev/null 2>&1; then
        echo "true"
    else
        echo "false"
    fi
}

existe_programa() {
    which "$1" >/dev/null 2>&1 && echo "si" || echo "no"
}

# Módulos predefinidos de Tryton
tryton_modules="
account
country
party
currency
company
product
stock
stock_supply
stock_secondary_unit
account_credit_limit
account_invoice
account_invoice_stock
account_product
account_payment_clearing
account_payment
sale
sale_opportunity
sale_product_customer
sale_credit_limit
sale_payment
sale_invoice_grouping
sale_discount
sale_supply
purchase
purchase_history
bank
"

clear
echo "#################################################"
echo "########### INSTALACION DE TRYTON ###############"
echo "###########      FREEBSD 15       ###############"
echo "###########      COMPLETA         ###############"
echo "#################################################"
echo ""

if [ "$(id -u)" != 0 ]; then
    printf "${RED}Este script necesita ser ejecutado como superusuario (root)${NC}\n"
    exit 1
fi

# Solicitar datos de configuración
printf "${BLUE}--- CONFIGURACIÓN DEL SISTEMA ---${NC}\n"
read -p "Usuario para el sistema: " user_sys
user_sys=$(echo "$user_sys" | xargs)

if [ "$user_sys" != '' ]; then
    if id "$user_sys" >/dev/null 2>&1; then
        printf "${RED}Error: El usuario $user_sys ya existe${NC}\n"
        exit 1
    fi
else
    printf "${RED}El usuario no puede estar en blanco${NC}\n"
    exit 1
fi

read -p "Desea instalar postgresql en local (Y/n): " inst_postgres
inst_postgres=$(echo "$inst_postgres" | tr '[:upper:]' '[:lower:]' | xargs)

if [ -z "$inst_postgres" ]; then
    inst_postgres="y"
    host_bd="localhost"
fi

while [ "$inst_postgres" != "y" ] && [ "$inst_postgres" != "n" ]; do
    printf "${YELLOW}Opción no válida. Por favor, ingrese 'y' o 'n'.${NC}\n"
    read -p "Desea instalar postgresql en local (Y/n): " inst_postgres
    inst_postgres=$(echo "$inst_postgres" | tr '[:upper:]' '[:lower:]' | xargs)
    if [ -z "$inst_postgres" ]; then
        inst_postgres="y"
        host_bd="localhost"
    fi
done

if [ "$inst_postgres" = "y" ]; then
    host_bd="localhost"
    echo -n "Password para el superusuario postgres: "
    stty -echo
    read pass_postgres
    stty echo
    echo ""
    pass_postgres=$(echo "$pass_postgres" | xargs)
fi

read -p "Version de tryton a instalar (ejemplo 7.0/7.2): " version_tryton
version_tryton=$(echo "$version_tryton" | xargs)

read -p "Codigo pais (ejemplo: es): " codigo_pais
codigo_pais=$(echo "$codigo_pais" | xargs)

read -p "Nombre base de datos: " nombre_bd
nombre_bd=$(echo "$nombre_bd" | xargs)

read -p "Directorio para instalación (defecto /opt/tryton): " directorio_instalacion
directorio_instalacion=$(echo "$directorio_instalacion" | xargs)

if [ -z "$directorio_instalacion" ]; then
    directorio_instalacion="/opt/tryton"
fi

if [ "$inst_postgres" = "n" ]; then
    read -p "Host base de datos: " host_bd
    host_bd=$(echo "$host_bd" | xargs)
fi

read -p "Puerto de conexion SAO tryton (default:8000): " puerto_tryton_sao
puerto_tryton_sao=$(echo "$puerto_tryton_sao" | xargs)
[ -z "$puerto_tryton_sao" ] && puerto_tryton_sao="8000"

read -p "Puerto de conexion xmlrpc tryton (default:8080): " puerto_tryton_xml
puerto_tryton_xml=$(echo "$puerto_tryton_xml" | xargs)
[ -z "$puerto_tryton_xml" ] && puerto_tryton_xml="8080"

read -p "Puerto base de datos (default:5432): " puerto_bd
puerto_bd=$(echo "$puerto_bd" | xargs)
[ -z "$puerto_bd" ] && puerto_bd="5432"

read -p "Usuario bd: " user_bd
user_bd=$(echo "$user_bd" | xargs)

echo -n "Password base de datos: "
stty -echo
read pass_bd
stty echo
echo ""
pass_bd=$(echo "$pass_bd" | xargs)


read -p "Nombre host para ssl (defecto gestion.local): " hots_name_ssl
hots_name_ssl=$(echo "$hots_name_ssl" | xargs)

if [ -z "$hots_name_ssl" ]; then
    hots_name_ssl="gestion.local"
fi

read -p "Desea instalar todos los modulos (Y/n): " confirmar_modulos
confirmar_modulos=$(echo "$confirmar_modulos" | tr '[:upper:]' '[:lower:]' | xargs)
[ -z "$confirmar_modulos" ] && confirmar_modulos="y"

while [ "$confirmar_modulos" != "y" ] && [ "$confirmar_modulos" != "n" ]; do
    read -p "Desea instalar todos los modulos (Y/n): " confirmar_modulos
    confirmar_modulos=$(echo "$confirmar_modulos" | tr '[:upper:]' '[:lower:]' | xargs)
    [ -z "$confirmar_modulos" ] && confirmar_modulos="y"
done

read -p "Quiere ponerlo en modo produccion (Y/n): " confirmar_produccion
confirmar_produccion=$(echo "$confirmar_produccion" | tr '[:upper:]' '[:lower:]' | xargs)
[ -z "$confirmar_produccion" ] && confirmar_produccion="y"

while [ "$confirmar_produccion" != "y" ] && [ "$confirmar_produccion" != "n" ]; do
    read -p "Quiere ponerlo en modo produccion (Y/n): " confirmar_produccion
    confirmar_produccion=$(echo "$confirmar_produccion" | tr '[:upper:]' '[:lower:]' | xargs)
    [ -z "$confirmar_produccion" ] && confirmar_produccion="y"
done


# Tipo de despliegue en producción
tipo_produccion=""

if [ "$confirmar_produccion" = "y" ]; then
    echo ""
    echo "Seleccione el tipo de despliegue:"
    echo "  1) Nginx + uWSGI"
    echo "  2) Solo uWSGI"

    while true; do
        read -p "Opción (1/2): " tipo_produccion
        tipo_produccion=$(echo "$tipo_produccion" | xargs)

        case "$tipo_produccion" in
            1|2)
                break
                ;;
            *)
                printf "${YELLOW}Opción no válida. Seleccione 1 o 2.${NC}\n"
                ;;
        esac
    done
fi


# Mostrar resumen
clear
echo "#################################################"
echo "######### DATOS PARA LA INSTALACION DE TRYTON ####"
echo "#################################################"
echo ""
echo "INSTALAR POSTGRES LOCALHOST............: $inst_postgres"
echo "VERSION DE TRYTON.......................: $version_tryton"
echo "CODIGO DE PAIS..........................: $codigo_pais"
echo "NOMBRE BASE DE DATOS....................: $nombre_bd"
echo "DIRECTORIO DE INSTALACION...............: $directorio_instalacion"
echo "PUERTO DE LA BASE DE DATOS..............: $puerto_bd"
echo "PUERTO SAO DE TRYTON....................: $puerto_tryton_sao"
echo "PUERTO XMLRPC DE TRYTON.................: $puerto_tryton_xml"
echo "HOST DE LA BASE DE DATOS................: $host_bd"
echo "USUARIO DE LA BASE DE DATOS.............: $user_bd"
echo "USUARIO PARA EL SISTEMA.................: $user_sys"
echo "NOMBRE HOST PARA SSL....................: $hots_name_ssl"
echo "INSTALAR TODOS LOS MODULOS..............: $confirmar_modulos"
echo "MODO PRODUCCION.........................: $confirmar_produccion"
echo "#################################################"
echo ""
read -p "DESEA CONFIRMAR ESTOS DATOS (Y/n): " confirmar
confirmar=$(echo "$confirmar" | tr '[:upper:]' '[:lower:]' | xargs)
[ -z "$confirmar" ] && confirmar="y"

if [ "$confirmar" != "y" ]; then
    printf "${RED}Proceso cancelado${NC}\n"
    exit 1
fi

printf "${GREEN}Iniciando instalación...${NC}\n"

# Actualizar repositorios e instalar paquetes
printf "${BLUE}=== Actualizando repositorios e instalando dependencias ===${NC}\n"
pkg install -y curl wget git npm node20
pkg install -y cups openldap26-client jpeg-turbo tiff libreoffice webfonts
pkg install -y python313 gcc gmake pkgconf rust libxml2 libxslt libffi libyaml

# Crear usuario con bash como shell
pw useradd "$user_sys" -m -d "$directorio_instalacion" -s /usr/local/bin/bash 2>/dev/null || true

# Crear estructura de directorios del sistema
printf "${BLUE}=== Creando directorios funcionales ===${NC}\n"
mkdir -p "$directorio_instalacion"/sao
mkdir -p "$directorio_instalacion"/config
mkdir -p "$directorio_instalacion"/log
mkdir -p "$directorio_instalacion"/storage_db
chmod 750 "$directorio_instalacion"/storage_db
mkdir -p "$directorio_instalacion"/download
# Creación de carpetas de la CA
mkdir -p "$directorio_instalacion"/ca         
mkdir -p "$directorio_instalacion"/ca/private 
mkdir -p "$directorio_instalacion"/ca/certs   
mkdir -p "$directorio_instalacion"/ca/csr     
mkdir -p "$directorio_instalacion"/ca/servers 
mkdir -p "$directorio_instalacion"/ca/clients 
mkdir -p "$directorio_instalacion"/ca/scripts 
mkdir -p "$directorio_instalacion"/ca/openssl 
mkdir -p "$directorio_instalacion"/ca_publica 

chmod 700 "$directorio_instalacion"/ca/private

# Obtener IP local (Compatibilidad FreeBSD)
IP_ADDR=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
HOSTNAME_TRYTON="$hots_name_ssl"

# Configuración de OpenSSL para Servidor y CA
cat > "$directorio_instalacion"/ca/openssl/server.cnf << EOF
[req]
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[dn]
C = ES
ST = Madrid
L = Madrid
O = Tryton
CN = ${HOSTNAME_TRYTON}

[req_ext]
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${HOSTNAME_TRYTON}
DNS.2 = localhost
IP.1 = ${IP_ADDR}
IP.2 = 127.0.0.1
EOF

cat > "$directorio_instalacion"/ca/openssl/ca.cnf << EOF
[req]
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = v3_ca

[dn]
C = ES
ST = Madrid
L = Madrid
O = Tryton
CN = Tryton Internal CA

[v3_ca]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
EOF

# Generación Criptográfica de la CA y Certificados (ECDSA)
if [ ! -f "$directorio_instalacion"/ca/private/myCA.key ]; then
    printf "${BLUE}Creando CA privada de alta eficiencia (ECDSA)...${NC}\n"
    openssl ecparam -name prime256v1 -genkey -noout -out "$directorio_instalacion"/ca/private/myCA.key
    chmod 600 "$directorio_instalacion"/ca/private/myCA.key
    openssl req -x509 -new -nodes -key "$directorio_instalacion"/ca/private/myCA.key -config "$directorio_instalacion"/ca/openssl/ca.cnf -days 3650 -out "$directorio_instalacion"/ca/certs/myCA.pem
fi

printf "${BLUE}Generando certificado SSL del servidor (ECDSA)...${NC}\n"
openssl ecparam -name prime256v1 -genkey -noout -out "$directorio_instalacion"/ca/servers/tryton.key
chmod 600 "$directorio_instalacion"/ca/servers/tryton.key
openssl req -new -key "$directorio_instalacion"/ca/servers/tryton.key -out "$directorio_instalacion"/ca/csr/tryton.csr -config "$directorio_instalacion"/ca/openssl/server.cnf
openssl x509 -req -in "$directorio_instalacion"/ca/csr/tryton.csr -CA "$directorio_instalacion"/ca/certs/myCA.pem -CAkey "$directorio_instalacion"/ca/private/myCA.key -CAcreateserial -out "$directorio_instalacion"/ca/servers/tryton.crt -days 1825 -sha256 -extensions req_ext -extfile "$directorio_instalacion"/ca/openssl/server.cnf
chmod 644 "$directorio_instalacion"/ca/servers/tryton.crt

# Escribir scripts auxiliares de la CA
cat > "$directorio_instalacion"/ca/scripts/renew_server_cert.sh << 'EOF'
#!/bin/sh
BASE_DIR=$(cd "$(dirname "$0")/.." && pwd)
openssl req -new -key "$BASE_DIR"/servers/tryton.key -out "$BASE_DIR"/csr/tryton.csr -config "$BASE_DIR"/openssl/server.cnf
openssl x509 -req -in "$BASE_DIR"/csr/tryton.csr -CA "$BASE_DIR"/certs/myCA.pem -CAkey "$BASE_DIR"/private/myCA.key -CAcreateserial -out "$BASE_DIR"/servers/tryton.crt -days 1825 -sha256 -extensions req_ext -extfile "$BASE_DIR"/openssl/server.cnf
EOF
chmod +x "$directorio_instalacion"/ca/scripts/renew_server_cert.sh

cat > "$directorio_instalacion"/ca/scripts/create_client_cert.sh << 'EOF'
#!/bin/sh
CLIENT_NAME=$1
if [ -z "$CLIENT_NAME" ]; then echo "Uso: ./create_client_cert.sh nombre_cliente"; exit 1; fi
BASE_DIR=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$BASE_DIR"/clients/$CLIENT_NAME
cat > "$BASE_DIR"/clients/$CLIENT_NAME/client.cnf << EXT_EOF
[req]
prompt = no
distinguished_name = dn
req_extensions = client_ext
[dn]
C = ES; ST = Madrid; L = Madrid; O = Tryton; CN = $CLIENT_NAME
[client_ext]
keyUsage = critical, digitalSignature
extendedKeyUsage = clientAuth
subjectAltName = DNS:$CLIENT_NAME
EXT_EOF
openssl ecparam -name prime256v1 -genkey -noout -out "$BASE_DIR"/clients/$CLIENT_NAME/$CLIENT_NAME.key
openssl req -new -key "$BASE_DIR"/clients/$CLIENT_NAME/$CLIENT_NAME.key -out "$BASE_DIR"/clients/$CLIENT_NAME/$CLIENT_NAME.csr -config "$BASE_DIR"/clients/$CLIENT_NAME/client.cnf
openssl x509 -req -in "$BASE_DIR"/clients/$CLIENT_NAME/$CLIENT_NAME.csr -CA "$BASE_DIR"/certs/myCA.pem -CAkey "$BASE_DIR"/private/myCA.key -CAcreateserial -out "$BASE_DIR"/clients/$CLIENT_NAME/$CLIENT_NAME.crt -days 1825 -sha256 -extensions client_ext -extfile "$BASE_DIR"/clients/$CLIENT_NAME/client.cnf
rm "$BASE_DIR"/clients/$CLIENT_NAME/client.cnf
EOF
chmod +x "$directorio_instalacion"/ca/scripts/create_client_cert.sh

cp "$directorio_instalacion"/ca/certs/myCA.pem "$directorio_instalacion"/ca_publica/myCA.crt
chmod 644 "$directorio_instalacion"/ca_publica/myCA.crt

# Instalar y Configurar PostgreSQL Local con degradación requerida a md5
if [ "$inst_postgres" = "y" ]; then
    printf "${BLUE}=== Instalando PostgreSQL 16 ===${NC}\n"
    pkg install -y postgresql16-server postgresql16-contrib
    sysrc postgresql_enable="YES"
    /usr/local/etc/rc.d/postgresql initdb

    PG_DATA="/var/db/postgres/data16"
    PG_CONF="$PG_DATA/postgresql.conf"
    PG_HBA="$PG_DATA/pg_hba.conf"

    if [ -f "$PG_CONF" ]; then
        cp "$PG_CONF" "$PG_CONF.bak"
        sed -i '' "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" "$PG_CONF"
        sed -i '' "s/#port = 5432/port = $puerto_bd/g" "$PG_CONF"
    fi

    /usr/local/etc/rc.d/postgresql start
    sleep 5

    su -m postgres -c "psql -c \"ALTER USER postgres WITH PASSWORD '$pass_postgres';\""
    su -m postgres -c "psql -c \"CREATE ROLE $user_bd WITH LOGIN SUPERUSER PASSWORD '$pass_bd';\"" 2>/dev/null || true
    su -m postgres -c "psql -c \"CREATE DATABASE $nombre_bd WITH OWNER $user_bd;\"" 2>/dev/null || true

    echo -e "${BLUE}Configurando autenticación md5 requerida...${NC}"
    if [ -f "$PG_HBA" ]; then
        cp "$PG_HBA" "$PG_HBA.bak"
        sed -i '' 's/trust$/md5/g'          "$PG_HBA"
        sed -i '' 's/ident$/md5/g'          "$PG_HBA"
        sed -i '' 's/peer$/md5/g'           "$PG_HBA"
        sed -i '' 's/scram-sha-256/md5/g'   "$PG_HBA"
    fi
    su -m postgres -c "psql -c 'SELECT pg_reload_conf();'"
fi

# Configurando Entorno Virtual Python e Instalar Dependencias
printf "${BLUE}=== Configurando venv Python e instalando Tryton ===${NC}\n"
cd "$directorio_instalacion"
su -m "$user_sys" -c "python3.13 -m venv ."

venv_pip() {
    su "$user_sys" -c "$directorio_instalacion/bin/pip install $1"
}

venv_pip "--upgrade pip setuptools wheel"
venv_pip "werkzeug ldap3 python-stdnum simpleeval cached_property requests stripe csb43 pyyaml future ofxparse zeep PyPDF2 wrapt python-sql python-dateutil polib genshi relatorio passlib lxml schwifty"
venv_pip "psycopg_pool bcrypt psycopg[c] uwsgi forex-python phonenumbers pygal qrcode[pil] email-validator"
venv_pip "trytond==$version_tryton.* proteus==$version_tryton.*"

# Descarga e instalación de módulos
if [ "$confirmar_modulos" = "y" ]; then
    MODULES_LIST=$(fetch -q -o - "https://downloads.tryton.org/$version_tryton/modules.txt" 2>/dev/null)
    if [ -n "$MODULES_LIST" ]; then
        for module in $MODULES_LIST; do
            venv_pip "trytond_$module==$version_tryton.*" 2>/dev/null || true
        done
    else
        for module in $tryton_modules; do
            venv_pip "trytond_$module==$version_tryton.*" 2>/dev/null || true
        done
    fi
else
    for module in $tryton_modules; do
        venv_pip "trytond_$module==$version_tryton.*" 2>/dev/null || true
    done
fi

# Instalación de SAO (Cliente Web)
printf "${BLUE}=== Instalando SAO web client ===${NC}\n"
cd "$directorio_instalacion"/download
fetch "https://downloads.tryton.org/$version_tryton/tryton-sao-last.tgz"
if [ -f "tryton-sao-last.tgz" ]; then
    tar xzf tryton-sao-last.tgz
    cp -r package/. "$directorio_instalacion"/sao/
    cd "$directorio_instalacion"/sao
    npm install --production --legacy-peer-deps 2>/dev/null || true
fi

# Logs y Archivos de Configuración de Tryton
touch "$directorio_instalacion"/log/tryton.log
touch "$directorio_instalacion"/log/tryton-cron.log
touch "$directorio_instalacion"/log/tryton-worker.log
chown "$user_sys":"$user_sys" "$directorio_instalacion"/log/*.log

cat > "$directorio_instalacion"/config/trytond.conf << EOF
[database]
# URI de conexión a PostgreSQL (sin nombre de BD: trytond lo gestiona por BD activa)
uri = postgresql://$user_bd:$pass_bd@$host_bd:$puerto_bd/
# Directorio raíz del FileStore (adjuntos, avatares, informes almacenados en disco)
# Ruta estándar del sistema, separada del directorio de la aplicación
path = $directorio_instalacion/storage_db
# almacenamiento de las imageens de lso avatares
avatar_filestore = False
avatar_prefix = avatar
# Idioma principal para almacenamiento de traducciones en BD
language = $codigo_pais

[web]
# Interfaz web (SAO y API JSON-RPC)
listen = 0.0.0.0:$puerto_tryton_sao
root = $directorio_instalacion/sao

[account_invoice]
# Almacenar adjuntos en disco (FileStore) en lugar de en la BD
filestore = False
# Prefijo de subdirectorio dentro del FileStore para los adjuntos
store_prefix = invoices

[account_statement]
# Almacenar adjuntos en disco (FileStore) en lugar de en la BD 
filestore = False
# Prefijo de subdirectorio dentro del FileStore para los adjuntos
store_prefix = account_statement

[document_incoming]
# Almacenar adjuntos en disco (FileStore) en lugar de en la BD 
filestore = False
# Prefijo de subdirectorio dentro del FileStore para los documentos del
#modulo document_incoming
store_prefix = document_incoming

[attachment]
# Almacenar adjuntos en disco (FileStore) en lugar de en la BD
filestore = False
# Prefijo de subdirectorio dentro del FileStore para los adjuntos
store_prefix = attachment

[session]
# The time (in seconds) until an inactive session is considered invalid for
# special internal tasks, thus requiring to re-confirm the session.
timeout = 300
# The time (in seconds) until a session expires.
max_age = 86400

# The maximal number of authentication attempts before the server answers
# unconditionally 'Too Many Requests'.
# The counting is done on all attempts over one period of timeout.
#max_attempt = 5

[password]
# The minimal length required for user passwords.
#length = 8

# The ratio of non repeated characters for user passwords.
entropy = 0.75

# The time (in seconds) until a reset password expires.
#reset_timeout = 86400   # (24h)

# The path to the INI file to load as CryptContext:
# <https://passlib.readthedocs.io/en/stable/narr/context-tutorial.html#loading-saving-a-cryptcontext>
# If no path is set, Tryton will use the schemes bcrypt or pbkdf2_sha512.
#passlib = None

[queue]
#Activate asynchronous processing of the tasks. Otherwise they are performed at the end of the requests
worker = False
clean_days = 30

[error]
clean_days = 120

[email]
uri = smtp://localhost:25
# from = "Company Inc" <info@example.com>
from = tryton@localhost
retry = 5

[product]
# The number of decimals with which the unit prices are stored
# in the database. The default value is 4.
# Warning: This setting can not be lowered once a database is created.
#price_decimal = 4

[ssl]
privatekey = $directorio_instalacion/ca/servers/tryton.key
certificate = $directorio_instalacion/ca/servers/tryton.crt
EOF

# Logs Rotativos
for logtype in "" "-cron" "-worker"; do
    cat > "$directorio_instalacion"/config/trytond-log${logtype}.conf << EOF
[formatters]
keys=simple
[handlers]
keys=rotate
[loggers]
keys=root
[formatter_simple]
format=[%(asctime)s] %(levelname)s:%(name)s:%(message)s
[handler_rotate]
class=handlers.TimedRotatingFileHandler
args=('$directorio_instalacion/log/tryton${logtype}.log', 'D', 1, 30)
formatter=simple
[logger_root]
level=INFO
handlers=rotate
EOF
done



# Inicialización del Esquema Base de Datos de Tryton
printf "${BLUE}Inicializando base de datos Tryton...${NC}\n"
su "$user_sys" -c "$directorio_instalacion/bin/trytond-admin -c $directorio_instalacion/config/trytond.conf -d $nombre_bd --all"

if [ $? -eq 0 ]; then
    su "$user_sys" -c "$directorio_instalacion/bin/trytond-admin -u account --activate-dependencies -d $nombre_bd -c $directorio_instalacion/config/trytond.conf"
 if [ -f "$directorio_instalacion/bin/trytond_import_countries" ]; then
        echo -e "${BLUE}Importando países...${NC}"
        su "$user_sys" -c "$directorio_instalacion/bin/trytond_import_countries -d $nombre_bd \
            -c $directorio_instalacion/config/trytond.conf"  || true
    fi


        if [ -f "$directorio_instalacion/bin/trytond_import_postal_codes" ]; then
        echo -e "${BLUE}Importando Codigos Postales...${NC}"
        su "$user_sys" -c "$directorio_instalacion/bin/trytond_import_postal_codes -d $nombre_bd \
            -c $directorio_instalacion/config/trytond.conf es"  || true
    fi

    if [ -f "$directorio_instalacion/bin/trytond_import_currencies" ]; then
        echo -e "${BLUE}Importando monedas...${NC}"
        su "$user_sys" -c "$directorio_instalacion/bin/trytond_import_currencies -d $nombre_bd \
            -c $directorio_instalacion/config/trytond.conf" 2>/dev/null || true
    fi
fi

# Permisos Finales Unificados sobre la instalación
chown -R "$user_sys":"$user_sys" "$directorio_instalacion"


# ===========================================================================
# CREACIÓN DE SERVICIOS INDEPENDIENTES (rc.d) EN FREEBSD
# ===========================================================================
printf "${BLUE}=== Generando scripts de servicios rc.d independientes ===${NC}\n"

mkdir -p /var/run/tryton
chown "$user_sys":"$user_sys" /var/run/tryton



# 1. Servicio NATIVO (trytond)
cat > /usr/local/etc/rc.d/trytond << EOF
#!/bin/sh
# PROVIDE: trytond
# REQUIRE: postgresql
# BEFORE: LOGIN
# KEYWORD: shutdown

. /etc/rc.subr

name="trytond"
rcvar="trytond_enable"
load_rc_config \$name

: \${trytond_enable:="NO"}
: \${trytond_user:="$user_sys"}
: \${trytond_home:="$directorio_instalacion"}

pidfile="/var/run/tryton/trytond.pid"

start_cmd="trytond_start"
stop_cmd="trytond_stop"
status_cmd="trytond_status"

trytond_status() {
    if [ -f \${pidfile} ] && kill -0 \$(cat \${pidfile}) 2>/dev/null; then
        echo "trytond is running as pid \$(cat \${pidfile})"
    else
        echo "trytond is not running"
        return 1
    fi
}

trytond_start() {
    echo "Starting trytond"
    cd \${trytond_home}
    /usr/sbin/daemon -u \${trytond_user} -f -p \${pidfile} \
        \${trytond_home}/bin/trytond \
        -c \${trytond_home}/config/trytond.conf \
        --logconf \${trytond_home}/config/trytond-log.conf \
        -d $nombre_bd
}

trytond_stop() {
    if [ -f \${pidfile} ]; then
        kill -TERM \$(cat \${pidfile})
        rm -f \${pidfile}
    fi
}

run_rc_command "\$1"
EOF

# Servicio cron
cat > /usr/local/etc/rc.d/trytond-cron << EOF
#!/bin/sh
# PROVIDE: trytond-cron
# REQUIRE: postgresql trytond
# KEYWORD: shutdown

. /etc/rc.subr

name="trytond_cron"
rcvar="trytond_cron_enable"
load_rc_config \$name

: \${trytond_cron_enable:="NO"}
: \${trytond_user:="$user_sys"}
: \${trytond_home:="$directorio_instalacion"}

pidfile="/var/run/tryton/trytond-cron.pid"

start_cmd="trytond_cron_start"
stop_cmd="trytond_cron_stop"
status_cmd="trytond_cron_status"

trytond_cron_status() {
    if [ -f \${pidfile} ] && kill -0 \$(cat \${pidfile}) 2>/dev/null; then
        echo "trytond_cron is running as pid \$(cat \${pidfile})"
    else
        echo "trytond_cron is not running"
        return 1
    fi
}

trytond_cron_start() {
    echo "Starting trytond-cron"
    cd \${trytond_home}
    /usr/sbin/daemon -u \${trytond_user} -f -p \${pidfile} \
        \${trytond_home}/bin/trytond-cron \
        -c \${trytond_home}/config/trytond.conf \
        --logconf \${trytond_home}/config/trytond-log-cron.conf \
        -d $nombre_bd
}

trytond_cron_stop() {
    if [ -f \${pidfile} ]; then
        kill -TERM \$(cat \${pidfile})
        rm -f \${pidfile}
    fi
}

run_rc_command "\$1"
EOF

# Servicio worker
cat > /usr/local/etc/rc.d/trytond-worker << EOF
#!/bin/sh
# PROVIDE: trytond-worker
# REQUIRE: postgresql trytond
# KEYWORD: shutdown

. /etc/rc.subr

name="trytond_worker"
rcvar="trytond_worker_enable"
load_rc_config \$name

: \${trytond_worker_enable:="NO"}
: \${trytond_user:="$user_sys"}
: \${trytond_home:="$directorio_instalacion"}

pidfile="/var/run/tryton/trytond-worker.pid"

start_cmd="trytond_worker_start"
stop_cmd="trytond_worker_stop"
status_cmd="trytond_worker_status"

trytond_worker_status() {
    if [ -f \${pidfile} ] && kill -0 \$(cat \${pidfile}) 2>/dev/null; then
        echo "trytond_worker is running as pid \$(cat \${pidfile})"
    else
        echo "trytond_worker is not running"
        return 1
    fi
}

trytond_worker_start() {
    echo "Starting trytond-worker"
    cd \${trytond_home}
    /usr/sbin/daemon -u \${trytond_user} -f -p \${pidfile} \
        \${trytond_home}/bin/trytond-worker \
        -c \${trytond_home}/config/trytond.conf \
        --logconf \${trytond_home}/config/trytond-log-worker.conf \
        -d $nombre_bd
}

trytond_worker_stop() {
    if [ -f \${pidfile} ]; then
        kill -TERM \$(cat \${pidfile})
        rm -f \${pidfile}
    fi
}

run_rc_command "\$1"
EOF


cat > /usr/local/etc/rc.d/trytond-uwsgi << EOF
#!/bin/sh
# PROVIDE: trytond_uwsgi
# REQUIRE: postgresql
# KEYWORD: shutdown

. /etc/rc.subr

name="trytond_uwsgi"
rcvar="trytond_uwsgi_enable"
load_rc_config \$name

: \${trytond_uwsgi_enable:="NO"}
: \${trytond_user:="$user_sys"}
: \${trytond_home:="$directorio_instalacion"}

pidfile="/var/run/tryton/trytond-uwsgi.pid"

start_cmd="trytond_uwsgi_start"
stop_cmd="trytond_uwsgi_stop"
status_cmd="trytond_uwsgi_status"

trytond_uwsgi_status() {
    if [ -f \${pidfile} ] && kill -0 \$(cat \${pidfile}) 2>/dev/null; then
        echo "trytond_uwsgi is running as pid \$(cat \${pidfile})"
    else
        echo "trytond_uwsgi is not running"
        return 1
    fi
}

trytond_uwsgi_start() {
    echo "Starting trytond-uwsgi"
    cd \${trytond_home}
    /usr/sbin/daemon -u \${trytond_user} -f -p \${pidfile} \
        \${trytond_home}/bin/uwsgi \
        --ini \${trytond_home}/config/uwsgi_trytond.conf
}

trytond_uwsgi_stop() {
    if [ -f \${pidfile} ]; then
        kill -TERM \$(cat \${pidfile})
        rm -f \${pidfile}
    fi
}

run_rc_command "\$1"
EOF

chmod +x /usr/local/etc/rc.d/trytond
chmod +x /usr/local/etc/rc.d/trytond-uwsgi
chmod +x /usr/local/etc/rc.d/trytond-cron
chmod +x /usr/local/etc/rc.d/trytond-worker


# ===========================================================================
# LÓGICA DE ACTIVACIÓN EXCLUSIVA BASADA EN LA SELECCIÓN DE PRODUCCIÓN
# ===========================================================================
sysrc trytond_cron_enable="YES"   # El planificador siempre corre
sysrc trytond_worker_enable="YES" # El procesador de tareas en cola siempre corre

if [ "$confirmar_produccion" = "y" ]; then

    case "$tipo_produccion" in
        1)
printf "${GREEN} Nginx + uWSGI.${NC}\n"
pkg install -y nginx
mkdir -p /usr/local/etc/nginx/sites-enabled

if ! grep -q "sites-enabled/\*.conf" /usr/local/etc/nginx/nginx.conf; then
    awk '
    /^http[[:space:]]*{/ { inhttp=1 }
    inhttp && /^}/ {
        print "    include /usr/local/etc/nginx/sites-enabled/*.conf;"
        inhttp=0
    }
    { print }
    ' /usr/local/etc/nginx/nginx.conf > /tmp/nginx.conf

    mv /tmp/nginx.conf /usr/local/etc/nginx/nginx.conf
fi


cat > "$directorio_instalacion"/config/uwsgi_trytond.conf << EOF
[uwsgi]
http-socket = 0.0.0.0:$puerto_tryton_sao
master = true
env = TRYTOND_CONFIG=$directorio_instalacion/config/trytond.conf
wsgi = trytond.application:app
processes = 4
threads = 2
virtualenv = $directorio_instalacion
die-on-term = true

EOF

cat >/usr/local/etc/nginx/sites-enabled/tryton_site.conf << EOF
server {
  listen 443 ssl ;
  listen [::]:443 ssl ;

  server_name "$IP_ADDR";
  ssl_certificate $directorio_instalacion/ca/servers/tryton.crt;
  ssl_certificate_key $directorio_instalacion/ca/servers/tryton.key;
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_prefer_server_ciphers on;
  ssl_verify_client optional_no_ca;

  location / {
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_pass http://127.0.0.1:8000;
  }
}

server {
  listen 80;
  listen [::]:80;

  server_name example.tryton.org;
  return 301 https://0.0.0.0$request_uri;
}

EOF
sysrc nginx_enable="YES"
sysrc trytond_uwsgi_enable="YES"
sysrc trytond_enable="NO"
service trytond-uwsgi start
service nginx start
            ;;
        2)
             printf "${GREEN} Solo uWSGI con SSL.${NC}\n"
            
cat > "$directorio_instalacion"/config/uwsgi_trytond.conf << EOF
[uwsgi]
#http-socket = 0.0.0.0:$puerto_tryton_sao
https-socket = 0.0.0.0:8000,$directorio_instalacion/ca/servers/tryton.crt,$directorio_instalacion/ca/servers/tryton.key
master = true
env = TRYTOND_CONFIG=$directorio_instalacion/config/trytond.conf
wsgi = trytond.application:app
processes = 4
threads = 2
virtualenv = $directorio_instalacion
die-on-term = true

EOF
sysrc trytond_uwsgi_enable="YES"
sysrc trytond_enable="NO"
service trytond-uwsgi start
    
            ;;

esac
else
    printf "${YELLOW}Modo Desarrollo. Activando Servidor Nativo y manteniendo uWSGI deshabilitado.${NC}\n"
    sysrc trytond_uwsgi_enable="NO"
    sysrc trytond_enable="YES"
    service trytond start
fi



service trytond-cron start
service trytond-worker start

printf "${GREEN}=== INSTALACIÓN COMPLETADA EN FREEBSD 15 ===${NC}\n"
printf "${YELLOW}Nota para el operario: Los 4 servicios funcionales fueron creados con éxito.${NC}\n"
printf "${YELLOW}Puede administrarlos libremente usando 'service [nombre_servicio] [start|stop]'${NC}\n"
#!/bin/sh
# Script de instalación de Tryton con PostgreSQL en FreeBSD 15
# Versión COMPLETA - Incluye SAO, npm, CA interna (ECDSA) y 4 servicios independientes

# Colores para output (compatibles con printf en FreeBSD)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Funciones de control
postgres_act() {
    if /usr/local/etc/rc.d/postgresql status >/dev/null 2>&1; then
        echo "true"
    else
        echo "false"
    fi
}

existe_programa() {
    which "$1" >/dev/null 2>&1 && echo "si" || echo "no"
}

# Módulos predefinidos de Tryton
tryton_modules="
account
country
party
currency
company
product
stock
stock_supply
stock_secondary_unit
account_credit_limit
account_invoice
account_invoice_stock
account_product
account_payment_clearing
account_payment
sale
sale_opportunity
sale_product_customer
sale_credit_limit
sale_payment
sale_invoice_grouping
sale_discount
sale_supply
purchase
purchase_history
bank
"

clear
echo "#################################################"
echo "########### INSTALACION DE TRYTON ###############"
echo "###########      FREEBSD 15       ###############"
echo "###########      COMPLETA         ###############"
echo "#################################################"
echo ""

if [ "$(id -u)" != 0 ]; then
    printf "${RED}Este script necesita ser ejecutado como superusuario (root)${NC}\n"
    exit 1
fi

# Solicitar datos de configuración
printf "${BLUE}--- CONFIGURACIÓN DEL SISTEMA ---${NC}\n"
read -p "Usuario para el sistema: " user_sys
user_sys=$(echo "$user_sys" | xargs)

if [ "$user_sys" != '' ]; then
    if id "$user_sys" >/dev/null 2>&1; then
        printf "${RED}Error: El usuario $user_sys ya existe${NC}\n"
        exit 1
    fi
else
    printf "${RED}El usuario no puede estar en blanco${NC}\n"
    exit 1
fi

read -p "Desea instalar postgresql en local (Y/n): " inst_postgres
inst_postgres=$(echo "$inst_postgres" | tr '[:upper:]' '[:lower:]' | xargs)

if [ -z "$inst_postgres" ]; then
    inst_postgres="y"
    host_bd="localhost"
fi

while [ "$inst_postgres" != "y" ] && [ "$inst_postgres" != "n" ]; do
    printf "${YELLOW}Opción no válida. Por favor, ingrese 'y' o 'n'.${NC}\n"
    read -p "Desea instalar postgresql en local (Y/n): " inst_postgres
    inst_postgres=$(echo "$inst_postgres" | tr '[:upper:]' '[:lower:]' | xargs)
    if [ -z "$inst_postgres" ]; then
        inst_postgres="y"
        host_bd="localhost"
    fi
done

if [ "$inst_postgres" = "y" ]; then
    host_bd="localhost"
    echo -n "Password para el superusuario postgres: "
    stty -echo
    read pass_postgres
    stty echo
    echo ""
    pass_postgres=$(echo "$pass_postgres" | xargs)
fi

read -p "Version de tryton a instalar (ejemplo 7.0/7.2): " version_tryton
version_tryton=$(echo "$version_tryton" | xargs)

read -p "Codigo pais (ejemplo: es): " codigo_pais
codigo_pais=$(echo "$codigo_pais" | xargs)

read -p "Nombre base de datos: " nombre_bd
nombre_bd=$(echo "$nombre_bd" | xargs)

read -p "Directorio para instalación (defecto /opt/tryton): " directorio_instalacion
directorio_instalacion=$(echo "$directorio_instalacion" | xargs)

if [ -z "$directorio_instalacion" ]; then
    directorio_instalacion="/opt/tryton"
fi

if [ "$inst_postgres" = "n" ]; then
    read -p "Host base de datos: " host_bd
    host_bd=$(echo "$host_bd" | xargs)
fi

read -p "Puerto de conexion SAO tryton (default:8000): " puerto_tryton_sao
puerto_tryton_sao=$(echo "$puerto_tryton_sao" | xargs)
[ -z "$puerto_tryton_sao" ] && puerto_tryton_sao="8000"

read -p "Puerto de conexion xmlrpc tryton (default:8080): " puerto_tryton_xml
puerto_tryton_xml=$(echo "$puerto_tryton_xml" | xargs)
[ -z "$puerto_tryton_xml" ] && puerto_tryton_xml="8080"

read -p "Puerto base de datos (default:5432): " puerto_bd
puerto_bd=$(echo "$puerto_bd" | xargs)
[ -z "$puerto_bd" ] && puerto_bd="5432"

read -p "Usuario bd: " user_bd
user_bd=$(echo "$user_bd" | xargs)

echo -n "Password base de datos: "
stty -echo
read pass_bd
stty echo
echo ""
pass_bd=$(echo "$pass_bd" | xargs)


read -p "Nombre host para ssl (defecto gestion.local): " hots_name_ssl
hots_name_ssl=$(echo "$hots_name_ssl" | xargs)

if [ -z "$hots_name_ssl" ]; then
    hots_name_ssl="gestion.local"
fi

read -p "Desea instalar todos los modulos (Y/n): " confirmar_modulos
confirmar_modulos=$(echo "$confirmar_modulos" | tr '[:upper:]' '[:lower:]' | xargs)
[ -z "$confirmar_modulos" ] && confirmar_modulos="y"

while [ "$confirmar_modulos" != "y" ] && [ "$confirmar_modulos" != "n" ]; do
    read -p "Desea instalar todos los modulos (Y/n): " confirmar_modulos
    confirmar_modulos=$(echo "$confirmar_modulos" | tr '[:upper:]' '[:lower:]' | xargs)
    [ -z "$confirmar_modulos" ] && confirmar_modulos="y"
done

read -p "Quiere ponerlo en modo produccion (Y/n): " confirmar_produccion
confirmar_produccion=$(echo "$confirmar_produccion" | tr '[:upper:]' '[:lower:]' | xargs)
[ -z "$confirmar_produccion" ] && confirmar_produccion="y"

while [ "$confirmar_produccion" != "y" ] && [ "$confirmar_produccion" != "n" ]; do
    read -p "Quiere ponerlo en modo produccion (Y/n): " confirmar_produccion
    confirmar_produccion=$(echo "$confirmar_produccion" | tr '[:upper:]' '[:lower:]' | xargs)
    [ -z "$confirmar_produccion" ] && confirmar_produccion="y"
done


# Tipo de despliegue en producción
tipo_produccion=""

if [ "$confirmar_produccion" = "y" ]; then
    echo ""
    echo "Seleccione el tipo de despliegue:"
    echo "  1) Nginx + uWSGI"
    echo "  2) Solo uWSGI"

    while true; do
        read -p "Opción (1/2): " tipo_produccion
        tipo_produccion=$(echo "$tipo_produccion" | xargs)

        case "$tipo_produccion" in
            1|2)
                break
                ;;
            *)
                printf "${YELLOW}Opción no válida. Seleccione 1 o 2.${NC}\n"
                ;;
        esac
    done
fi


# Mostrar resumen
clear
echo "#################################################"
echo "######### DATOS PARA LA INSTALACION DE TRYTON ####"
echo "#################################################"
echo ""
echo "INSTALAR POSTGRES LOCALHOST............: $inst_postgres"
echo "VERSION DE TRYTON.......................: $version_tryton"
echo "CODIGO DE PAIS..........................: $codigo_pais"
echo "NOMBRE BASE DE DATOS....................: $nombre_bd"
echo "DIRECTORIO DE INSTALACION...............: $directorio_instalacion"
echo "PUERTO DE LA BASE DE DATOS..............: $puerto_bd"
echo "PUERTO SAO DE TRYTON....................: $puerto_tryton_sao"
echo "PUERTO XMLRPC DE TRYTON.................: $puerto_tryton_xml"
echo "HOST DE LA BASE DE DATOS................: $host_bd"
echo "USUARIO DE LA BASE DE DATOS.............: $user_bd"
echo "USUARIO PARA EL SISTEMA.................: $user_sys"
echo "NOMBRE HOST PARA SSL....................: $hots_name_ssl"
echo "INSTALAR TODOS LOS MODULOS..............: $confirmar_modulos"
echo "MODO PRODUCCION.........................: $confirmar_produccion"
echo "#################################################"
echo ""
read -p "DESEA CONFIRMAR ESTOS DATOS (Y/n): " confirmar
confirmar=$(echo "$confirmar" | tr '[:upper:]' '[:lower:]' | xargs)
[ -z "$confirmar" ] && confirmar="y"

if [ "$confirmar" != "y" ]; then
    printf "${RED}Proceso cancelado${NC}\n"
    exit 1
fi

printf "${GREEN}Iniciando instalación...${NC}\n"

# Actualizar repositorios e instalar paquetes
printf "${BLUE}=== Actualizando repositorios e instalando dependencias ===${NC}\n"
pkg install -y curl wget git npm node20
pkg install -y cups openldap26-client jpeg-turbo tiff libreoffice webfonts
pkg install -y python313 gcc gmake pkgconf rust libxml2 libxslt libffi libyaml

# Crear usuario con bash como shell
pw useradd "$user_sys" -m -d "$directorio_instalacion" -s /usr/local/bin/bash 2>/dev/null || true

# Crear estructura de directorios del sistema
printf "${BLUE}=== Creando directorios funcionales ===${NC}\n"
mkdir -p "$directorio_instalacion"/sao
mkdir -p "$directorio_instalacion"/config
mkdir -p "$directorio_instalacion"/log
mkdir -p "$directorio_instalacion"/storage_db
chmod 750 "$directorio_instalacion"/storage_db
mkdir -p "$directorio_instalacion"/download
# Creación de carpetas de la CA
mkdir -p "$directorio_instalacion"/ca         
mkdir -p "$directorio_instalacion"/ca/private 
mkdir -p "$directorio_instalacion"/ca/certs   
mkdir -p "$directorio_instalacion"/ca/csr     
mkdir -p "$directorio_instalacion"/ca/servers 
mkdir -p "$directorio_instalacion"/ca/clients 
mkdir -p "$directorio_instalacion"/ca/scripts 
mkdir -p "$directorio_instalacion"/ca/openssl 
mkdir -p "$directorio_instalacion"/ca_publica 

chmod 700 "$directorio_instalacion"/ca/private

# Obtener IP local (Compatibilidad FreeBSD)
IP_ADDR=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
HOSTNAME_TRYTON="$hots_name_ssl"

# Configuración de OpenSSL para Servidor y CA
cat > "$directorio_instalacion"/ca/openssl/server.cnf << EOF
[req]
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[dn]
C = ES
ST = Madrid
L = Madrid
O = Tryton
CN = ${HOSTNAME_TRYTON}

[req_ext]
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${HOSTNAME_TRYTON}
DNS.2 = localhost
IP.1 = ${IP_ADDR}
IP.2 = 127.0.0.1
EOF

cat > "$directorio_instalacion"/ca/openssl/ca.cnf << EOF
[req]
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = v3_ca

[dn]
C = ES
ST = Madrid
L = Madrid
O = Tryton
CN = Tryton Internal CA

[v3_ca]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
EOF

# Generación Criptográfica de la CA y Certificados (ECDSA)
if [ ! -f "$directorio_instalacion"/ca/private/myCA.key ]; then
    printf "${BLUE}Creando CA privada de alta eficiencia (ECDSA)...${NC}\n"
    openssl ecparam -name prime256v1 -genkey -noout -out "$directorio_instalacion"/ca/private/myCA.key
    chmod 600 "$directorio_instalacion"/ca/private/myCA.key
    openssl req -x509 -new -nodes -key "$directorio_instalacion"/ca/private/myCA.key -config "$directorio_instalacion"/ca/openssl/ca.cnf -days 3650 -out "$directorio_instalacion"/ca/certs/myCA.pem
fi

printf "${BLUE}Generando certificado SSL del servidor (ECDSA)...${NC}\n"
openssl ecparam -name prime256v1 -genkey -noout -out "$directorio_instalacion"/ca/servers/tryton.key
chmod 600 "$directorio_instalacion"/ca/servers/tryton.key
openssl req -new -key "$directorio_instalacion"/ca/servers/tryton.key -out "$directorio_instalacion"/ca/csr/tryton.csr -config "$directorio_instalacion"/ca/openssl/server.cnf
openssl x509 -req -in "$directorio_instalacion"/ca/csr/tryton.csr -CA "$directorio_instalacion"/ca/certs/myCA.pem -CAkey "$directorio_instalacion"/ca/private/myCA.key -CAcreateserial -out "$directorio_instalacion"/ca/servers/tryton.crt -days 1825 -sha256 -extensions req_ext -extfile "$directorio_instalacion"/ca/openssl/server.cnf
chmod 644 "$directorio_instalacion"/ca/servers/tryton.crt

# Escribir scripts auxiliares de la CA
cat > "$directorio_instalacion"/ca/scripts/renew_server_cert.sh << 'EOF'
#!/bin/sh
BASE_DIR=$(cd "$(dirname "$0")/.." && pwd)
openssl req -new -key "$BASE_DIR"/servers/tryton.key -out "$BASE_DIR"/csr/tryton.csr -config "$BASE_DIR"/openssl/server.cnf
openssl x509 -req -in "$BASE_DIR"/csr/tryton.csr -CA "$BASE_DIR"/certs/myCA.pem -CAkey "$BASE_DIR"/private/myCA.key -CAcreateserial -out "$BASE_DIR"/servers/tryton.crt -days 1825 -sha256 -extensions req_ext -extfile "$BASE_DIR"/openssl/server.cnf
EOF
chmod +x "$directorio_instalacion"/ca/scripts/renew_server_cert.sh

cat > "$directorio_instalacion"/ca/scripts/create_client_cert.sh << 'EOF'
#!/bin/sh
CLIENT_NAME=$1
if [ -z "$CLIENT_NAME" ]; then echo "Uso: ./create_client_cert.sh nombre_cliente"; exit 1; fi
BASE_DIR=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$BASE_DIR"/clients/$CLIENT_NAME
cat > "$BASE_DIR"/clients/$CLIENT_NAME/client.cnf << EXT_EOF
[req]
prompt = no
distinguished_name = dn
req_extensions = client_ext
[dn]
C = ES; ST = Madrid; L = Madrid; O = Tryton; CN = $CLIENT_NAME
[client_ext]
keyUsage = critical, digitalSignature
extendedKeyUsage = clientAuth
subjectAltName = DNS:$CLIENT_NAME
EXT_EOF
openssl ecparam -name prime256v1 -genkey -noout -out "$BASE_DIR"/clients/$CLIENT_NAME/$CLIENT_NAME.key
openssl req -new -key "$BASE_DIR"/clients/$CLIENT_NAME/$CLIENT_NAME.key -out "$BASE_DIR"/clients/$CLIENT_NAME/$CLIENT_NAME.csr -config "$BASE_DIR"/clients/$CLIENT_NAME/client.cnf
openssl x509 -req -in "$BASE_DIR"/clients/$CLIENT_NAME/$CLIENT_NAME.csr -CA "$BASE_DIR"/certs/myCA.pem -CAkey "$BASE_DIR"/private/myCA.key -CAcreateserial -out "$BASE_DIR"/clients/$CLIENT_NAME/$CLIENT_NAME.crt -days 1825 -sha256 -extensions client_ext -extfile "$BASE_DIR"/clients/$CLIENT_NAME/client.cnf
rm "$BASE_DIR"/clients/$CLIENT_NAME/client.cnf
EOF
chmod +x "$directorio_instalacion"/ca/scripts/create_client_cert.sh

cp "$directorio_instalacion"/ca/certs/myCA.pem "$directorio_instalacion"/ca_publica/myCA.crt
chmod 644 "$directorio_instalacion"/ca_publica/myCA.crt

# Instalar y Configurar PostgreSQL Local con degradación requerida a md5
if [ "$inst_postgres" = "y" ]; then
    printf "${BLUE}=== Instalando PostgreSQL 16 ===${NC}\n"
    pkg install -y postgresql16-server postgresql16-contrib
    sysrc postgresql_enable="YES"
    /usr/local/etc/rc.d/postgresql initdb

    PG_DATA="/var/db/postgres/data16"
    PG_CONF="$PG_DATA/postgresql.conf"
    PG_HBA="$PG_DATA/pg_hba.conf"

    if [ -f "$PG_CONF" ]; then
        cp "$PG_CONF" "$PG_CONF.bak"
        sed -i '' "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" "$PG_CONF"
        sed -i '' "s/#port = 5432/port = $puerto_bd/g" "$PG_CONF"
    fi

    /usr/local/etc/rc.d/postgresql start
    sleep 5

    su -m postgres -c "psql -c \"ALTER USER postgres WITH PASSWORD '$pass_postgres';\""
    su -m postgres -c "psql -c \"CREATE ROLE $user_bd WITH LOGIN SUPERUSER PASSWORD '$pass_bd';\"" 2>/dev/null || true
    su -m postgres -c "psql -c \"CREATE DATABASE $nombre_bd WITH OWNER $user_bd;\"" 2>/dev/null || true

    echo -e "${BLUE}Configurando autenticación md5 requerida...${NC}"
    if [ -f "$PG_HBA" ]; then
        cp "$PG_HBA" "$PG_HBA.bak"
        sed -i '' 's/trust$/md5/g'          "$PG_HBA"
        sed -i '' 's/ident$/md5/g'          "$PG_HBA"
        sed -i '' 's/peer$/md5/g'           "$PG_HBA"
        sed -i '' 's/scram-sha-256/md5/g'   "$PG_HBA"
    fi
    su -m postgres -c "psql -c 'SELECT pg_reload_conf();'"
fi

# Configurando Entorno Virtual Python e Instalar Dependencias
printf "${BLUE}=== Configurando venv Python e instalando Tryton ===${NC}\n"
cd "$directorio_instalacion"
su -m "$user_sys" -c "python3.13 -m venv ."

venv_pip() {
    su "$user_sys" -c "$directorio_instalacion/bin/pip install $1"
}

venv_pip "--upgrade pip setuptools wheel"
venv_pip "werkzeug ldap3 python-stdnum simpleeval cached_property requests stripe csb43 pyyaml future ofxparse zeep PyPDF2 wrapt python-sql python-dateutil polib genshi relatorio passlib lxml schwifty"
venv_pip "psycopg_pool bcrypt psycopg[c] uwsgi forex-python phonenumbers pygal qrcode[pil] email-validator"
venv_pip "trytond==$version_tryton.* proteus==$version_tryton.*"

# Descarga e instalación de módulos
if [ "$confirmar_modulos" = "y" ]; then
    MODULES_LIST=$(fetch -q -o - "https://downloads.tryton.org/$version_tryton/modules.txt" 2>/dev/null)
    if [ -n "$MODULES_LIST" ]; then
        for module in $MODULES_LIST; do
            venv_pip "trytond_$module==$version_tryton.*" 2>/dev/null || true
        done
    else
        for module in $tryton_modules; do
            venv_pip "trytond_$module==$version_tryton.*" 2>/dev/null || true
        done
    fi
else
    for module in $tryton_modules; do
        venv_pip "trytond_$module==$version_tryton.*" 2>/dev/null || true
    done
fi

# Instalación de SAO (Cliente Web)
printf "${BLUE}=== Instalando SAO web client ===${NC}\n"
cd "$directorio_instalacion"/download
fetch "https://downloads.tryton.org/$version_tryton/tryton-sao-last.tgz"
if [ -f "tryton-sao-last.tgz" ]; then
    tar xzf tryton-sao-last.tgz
    cp -r package/. "$directorio_instalacion"/sao/
    cd "$directorio_instalacion"/sao
    npm install --production --legacy-peer-deps 2>/dev/null || true
fi

# Logs y Archivos de Configuración de Tryton
touch "$directorio_instalacion"/log/tryton.log
touch "$directorio_instalacion"/log/tryton-cron.log
touch "$directorio_instalacion"/log/tryton-worker.log
chown "$user_sys":"$user_sys" "$directorio_instalacion"/log/*.log

cat > "$directorio_instalacion"/config/trytond.conf << EOF
[database]
# URI de conexión a PostgreSQL (sin nombre de BD: trytond lo gestiona por BD activa)
uri = postgresql://$user_bd:$pass_bd@$host_bd:$puerto_bd/
# Directorio raíz del FileStore (adjuntos, avatares, informes almacenados en disco)
# Ruta estándar del sistema, separada del directorio de la aplicación
path = $directorio_instalacion/storage_db
# almacenamiento de las imageens de lso avatares
avatar_filestore = False
avatar_prefix = avatar
# Idioma principal para almacenamiento de traducciones en BD
language = $codigo_pais

[web]
# Interfaz web (SAO y API JSON-RPC)
listen = 0.0.0.0:$puerto_tryton_sao
root = $directorio_instalacion/sao

[account_invoice]
# Almacenar adjuntos en disco (FileStore) en lugar de en la BD
filestore = False
# Prefijo de subdirectorio dentro del FileStore para los adjuntos
store_prefix = invoices

[account_statement]
# Almacenar adjuntos en disco (FileStore) en lugar de en la BD 
filestore = False
# Prefijo de subdirectorio dentro del FileStore para los adjuntos
store_prefix = account_statement

[document_incoming]
# Almacenar adjuntos en disco (FileStore) en lugar de en la BD 
filestore = False
# Prefijo de subdirectorio dentro del FileStore para los documentos del
#modulo document_incoming
store_prefix = document_incoming

[attachment]
# Almacenar adjuntos en disco (FileStore) en lugar de en la BD
filestore = False
# Prefijo de subdirectorio dentro del FileStore para los adjuntos
store_prefix = attachment

[session]
# The time (in seconds) until an inactive session is considered invalid for
# special internal tasks, thus requiring to re-confirm the session.
timeout = 300
# The time (in seconds) until a session expires.
max_age = 86400

# The maximal number of authentication attempts before the server answers
# unconditionally 'Too Many Requests'.
# The counting is done on all attempts over one period of timeout.
#max_attempt = 5

[password]
# The minimal length required for user passwords.
#length = 8

# The ratio of non repeated characters for user passwords.
entropy = 0.75

# The time (in seconds) until a reset password expires.
#reset_timeout = 86400   # (24h)

# The path to the INI file to load as CryptContext:
# <https://passlib.readthedocs.io/en/stable/narr/context-tutorial.html#loading-saving-a-cryptcontext>
# If no path is set, Tryton will use the schemes bcrypt or pbkdf2_sha512.
#passlib = None

[queue]
#Activate asynchronous processing of the tasks. Otherwise they are performed at the end of the requests
worker = False
clean_days = 30

[error]
clean_days = 120

[email]
uri = smtp://localhost:25
# from = "Company Inc" <info@example.com>
from = tryton@localhost
retry = 5

[product]
# The number of decimals with which the unit prices are stored
# in the database. The default value is 4.
# Warning: This setting can not be lowered once a database is created.
#price_decimal = 4

[ssl]
privatekey = $directorio_instalacion/ca/servers/tryton.key
certificate = $directorio_instalacion/ca/servers/tryton.crt
EOF

# Logs Rotativos
for logtype in "" "-cron" "-worker"; do
    cat > "$directorio_instalacion"/config/trytond-log${logtype}.conf << EOF
[formatters]
keys=simple
[handlers]
keys=rotate
[loggers]
keys=root
[formatter_simple]
format=[%(asctime)s] %(levelname)s:%(name)s:%(message)s
[handler_rotate]
class=handlers.TimedRotatingFileHandler
args=('$directorio_instalacion/log/tryton${logtype}.log', 'D', 1, 30)
formatter=simple
[logger_root]
level=INFO
handlers=rotate
EOF
done



# Inicialización del Esquema Base de Datos de Tryton
printf "${BLUE}Inicializando base de datos Tryton...${NC}\n"
su "$user_sys" -c "$directorio_instalacion/bin/trytond-admin -c $directorio_instalacion/config/trytond.conf -d $nombre_bd --all"

if [ $? -eq 0 ]; then
    su "$user_sys" -c "$directorio_instalacion/bin/trytond-admin -u account --activate-dependencies -d $nombre_bd -c $directorio_instalacion/config/trytond.conf"
 if [ -f "$directorio_instalacion/bin/trytond_import_countries" ]; then
        echo -e "${BLUE}Importando países...${NC}"
        su "$user_sys" -c "$directorio_instalacion/bin/trytond_import_countries -d $nombre_bd \
            -c $directorio_instalacion/config/trytond.conf"  || true
    fi


        if [ -f "$directorio_instalacion/bin/trytond_import_postal_codes" ]; then
        echo -e "${BLUE}Importando Codigos Postales...${NC}"
        su "$user_sys" -c "$directorio_instalacion/bin/trytond_import_postal_codes -d $nombre_bd \
            -c $directorio_instalacion/config/trytond.conf es"  || true
    fi

    if [ -f "$directorio_instalacion/bin/trytond_import_currencies" ]; then
        echo -e "${BLUE}Importando monedas...${NC}"
        su "$user_sys" -c "$directorio_instalacion/bin/trytond_import_currencies -d $nombre_bd \
            -c $directorio_instalacion/config/trytond.conf" 2>/dev/null || true
    fi
fi

# Permisos Finales Unificados sobre la instalación
chown -R "$user_sys":"$user_sys" "$directorio_instalacion"


# ===========================================================================
# CREACIÓN DE SERVICIOS INDEPENDIENTES (rc.d) EN FREEBSD
# ===========================================================================
printf "${BLUE}=== Generando scripts de servicios rc.d independientes ===${NC}\n"

mkdir -p /var/run/tryton
chown "$user_sys":"$user_sys" /var/run/tryton



# 1. Servicio NATIVO (trytond)
cat > /usr/local/etc/rc.d/trytond << EOF
#!/bin/sh
# PROVIDE: trytond
# REQUIRE: postgresql
# BEFORE: LOGIN
# KEYWORD: shutdown

. /etc/rc.subr

name="trytond"
rcvar="trytond_enable"
load_rc_config \$name

: \${trytond_enable:="NO"}
: \${trytond_user:="$user_sys"}
: \${trytond_home:="$directorio_instalacion"}

pidfile="/var/run/tryton/trytond.pid"

start_cmd="trytond_start"
stop_cmd="trytond_stop"
status_cmd="trytond_status"

trytond_status() {
    if [ -f \${pidfile} ] && kill -0 \$(cat \${pidfile}) 2>/dev/null; then
        echo "trytond is running as pid \$(cat \${pidfile})"
    else
        echo "trytond is not running"
        return 1
    fi
}

trytond_start() {
    echo "Starting trytond"
    cd \${trytond_home}
    /usr/sbin/daemon -u \${trytond_user} -f -p \${pidfile} \
        \${trytond_home}/bin/trytond \
        -c \${trytond_home}/config/trytond.conf \
        --logconf \${trytond_home}/config/trytond-log.conf \
        -d $nombre_bd
}

trytond_stop() {
    if [ -f \${pidfile} ]; then
        kill -TERM \$(cat \${pidfile})
        rm -f \${pidfile}
    fi
}

run_rc_command "\$1"
EOF

# Servicio cron
cat > /usr/local/etc/rc.d/trytond-cron << EOF
#!/bin/sh
# PROVIDE: trytond-cron
# REQUIRE: postgresql trytond
# KEYWORD: shutdown

. /etc/rc.subr

name="trytond_cron"
rcvar="trytond_cron_enable"
load_rc_config \$name

: \${trytond_cron_enable:="NO"}
: \${trytond_user:="$user_sys"}
: \${trytond_home:="$directorio_instalacion"}

pidfile="/var/run/tryton/trytond-cron.pid"

start_cmd="trytond_cron_start"
stop_cmd="trytond_cron_stop"
status_cmd="trytond_cron_status"

trytond_cron_status() {
    if [ -f \${pidfile} ] && kill -0 \$(cat \${pidfile}) 2>/dev/null; then
        echo "trytond_cron is running as pid \$(cat \${pidfile})"
    else
        echo "trytond_cron is not running"
        return 1
    fi
}

trytond_cron_start() {
    echo "Starting trytond-cron"
    cd \${trytond_home}
    /usr/sbin/daemon -u \${trytond_user} -f -p \${pidfile} \
        \${trytond_home}/bin/trytond-cron \
        -c \${trytond_home}/config/trytond.conf \
        --logconf \${trytond_home}/config/trytond-log-cron.conf \
        -d $nombre_bd
}

trytond_cron_stop() {
    if [ -f \${pidfile} ]; then
        kill -TERM \$(cat \${pidfile})
        rm -f \${pidfile}
    fi
}

run_rc_command "\$1"
EOF

# Servicio worker
cat > /usr/local/etc/rc.d/trytond-worker << EOF
#!/bin/sh
# PROVIDE: trytond-worker
# REQUIRE: postgresql trytond
# KEYWORD: shutdown

. /etc/rc.subr

name="trytond_worker"
rcvar="trytond_worker_enable"
load_rc_config \$name

: \${trytond_worker_enable:="NO"}
: \${trytond_user:="$user_sys"}
: \${trytond_home:="$directorio_instalacion"}

pidfile="/var/run/tryton/trytond-worker.pid"

start_cmd="trytond_worker_start"
stop_cmd="trytond_worker_stop"
status_cmd="trytond_worker_status"

trytond_worker_status() {
    if [ -f \${pidfile} ] && kill -0 \$(cat \${pidfile}) 2>/dev/null; then
        echo "trytond_worker is running as pid \$(cat \${pidfile})"
    else
        echo "trytond_worker is not running"
        return 1
    fi
}

trytond_worker_start() {
    echo "Starting trytond-worker"
    cd \${trytond_home}
    /usr/sbin/daemon -u \${trytond_user} -f -p \${pidfile} \
        \${trytond_home}/bin/trytond-worker \
        -c \${trytond_home}/config/trytond.conf \
        --logconf \${trytond_home}/config/trytond-log-worker.conf \
        -d $nombre_bd
}

trytond_worker_stop() {
    if [ -f \${pidfile} ]; then
        kill -TERM \$(cat \${pidfile})
        rm -f \${pidfile}
    fi
}

run_rc_command "\$1"
EOF


cat > /usr/local/etc/rc.d/trytond-uwsgi << EOF
#!/bin/sh
# PROVIDE: trytond_uwsgi
# REQUIRE: postgresql
# KEYWORD: shutdown

. /etc/rc.subr

name="trytond_uwsgi"
rcvar="trytond_uwsgi_enable"
load_rc_config \$name

: \${trytond_uwsgi_enable:="NO"}
: \${trytond_user:="$user_sys"}
: \${trytond_home:="$directorio_instalacion"}

pidfile="/var/run/tryton/trytond-uwsgi.pid"

start_cmd="trytond_uwsgi_start"
stop_cmd="trytond_uwsgi_stop"
status_cmd="trytond_uwsgi_status"

trytond_uwsgi_status() {
    if [ -f \${pidfile} ] && kill -0 \$(cat \${pidfile}) 2>/dev/null; then
        echo "trytond_uwsgi is running as pid \$(cat \${pidfile})"
    else
        echo "trytond_uwsgi is not running"
        return 1
    fi
}

trytond_uwsgi_start() {
    echo "Starting trytond-uwsgi"
    cd \${trytond_home}
    /usr/sbin/daemon -u \${trytond_user} -f -p \${pidfile} \
        \${trytond_home}/bin/uwsgi \
        --ini \${trytond_home}/config/uwsgi_trytond.conf
}

trytond_uwsgi_stop() {
    if [ -f \${pidfile} ]; then
        kill -TERM \$(cat \${pidfile})
        rm -f \${pidfile}
    fi
}

run_rc_command "\$1"
EOF

chmod +x /usr/local/etc/rc.d/trytond
chmod +x /usr/local/etc/rc.d/trytond-uwsgi
chmod +x /usr/local/etc/rc.d/trytond-cron
chmod +x /usr/local/etc/rc.d/trytond-worker


# ===========================================================================
# LÓGICA DE ACTIVACIÓN EXCLUSIVA BASADA EN LA SELECCIÓN DE PRODUCCIÓN
# ===========================================================================
sysrc trytond_cron_enable="YES"   # El planificador siempre corre
sysrc trytond_worker_enable="YES" # El procesador de tareas en cola siempre corre

if [ "$confirmar_produccion" = "y" ]; then

    case "$tipo_produccion" in
        1)
printf "${GREEN} Nginx + uWSGI.${NC}\n"
pkg install -y nginx
mkdir -p /usr/local/etc/nginx/sites-enabled

if ! grep -q "sites-enabled/\*.conf" /usr/local/etc/nginx/nginx.conf; then
    awk '
    /^http[[:space:]]*{/ { inhttp=1 }
    inhttp && /^}/ {
        print "    include /usr/local/etc/nginx/sites-enabled/*.conf;"
        inhttp=0
    }
    { print }
    ' /usr/local/etc/nginx/nginx.conf > /tmp/nginx.conf

    mv /tmp/nginx.conf /usr/local/etc/nginx/nginx.conf
fi


cat > "$directorio_instalacion"/config/uwsgi_trytond.conf << EOF
[uwsgi]
http-socket = 0.0.0.0:$puerto_tryton_sao
master = true
env = TRYTOND_CONFIG=$directorio_instalacion/config/trytond.conf
wsgi = trytond.application:app
processes = 4
threads = 2
virtualenv = $directorio_instalacion
die-on-term = true

EOF

cat >/usr/local/etc/nginx/sites-enabled/tryton_site.conf << EOF
server {
  listen 443 ssl ;
  listen [::]:443 ssl ;

  server_name "$IP_ADDR";
  ssl_certificate $directorio_instalacion/ca/servers/tryton.crt;
  ssl_certificate_key $directorio_instalacion/ca/servers/tryton.key;
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_prefer_server_ciphers on;
  ssl_verify_client optional_no_ca;

  location / {
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_pass http://127.0.0.1:8000;
  }
}

server {
  listen 80;
  listen [::]:80;

  server_name example.tryton.org;
  return 301 https://0.0.0.0$request_uri;
}

EOF
sysrc nginx_enable="YES"
sysrc trytond_uwsgi_enable="YES"
sysrc trytond_enable="NO"
service trytond-uwsgi start
service nginx start
            ;;
        2)
             printf "${GREEN} Solo uWSGI con SSL.${NC}\n"
            
cat > "$directorio_instalacion"/config/uwsgi_trytond.conf << EOF
[uwsgi]
#http-socket = 0.0.0.0:$puerto_tryton_sao
https-socket = 0.0.0.0:8000,$directorio_instalacion/ca/servers/tryton.crt,$directorio_instalacion/ca/servers/tryton.key
master = true
env = TRYTOND_CONFIG=$directorio_instalacion/config/trytond.conf
wsgi = trytond.application:app
processes = 4
threads = 2
virtualenv = $directorio_instalacion
die-on-term = true

EOF
sysrc trytond_uwsgi_enable="YES"
sysrc trytond_enable="NO"
service trytond_uwsgi start
    
            ;;

esac
else
    printf "${YELLOW}Modo Desarrollo. Activando Servidor Nativo y manteniendo uWSGI deshabilitado.${NC}\n"
    sysrc trytond_uwsgi_enable="NO"
    sysrc trytond_enable="YES"
    service trytond start
fi



service trytond-cron start
service trytond-worker start

printf "${GREEN}=== INSTALACIÓN COMPLETADA EN FREEBSD 15 ===${NC}\n"
printf "${YELLOW}Nota para el operario: Los 4 servicios funcionales fueron creados con éxito.${NC}\n"
printf "${YELLOW}Puede administrarlos libremente usando 'service [nombre_servicio] [start|stop]'${NC}\n"
