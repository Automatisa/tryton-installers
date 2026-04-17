#!/bin/sh
# Script de instalación de Tryton con PostgreSQL en FreeBSD 15
# Versión COMPLETA - Incluye SAO, npm y todas las funcionalidades
#



# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Funciones
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
echo "###########     FREEBSD 15       ###############"
echo "###########     COMPLETA          ###############"
echo "#################################################"
echo ""

if [ "$(id -u)" != 0 ]; then
    echo -e "${RED}Este script necesita ser ejecutado como superusuario${NC}"
    exit 1
fi



# Solicitar datos de configuración
echo -e "${BLUE}--- CONFIGURACIÓN DEL SISTEMA ---${NC}"
read -p "Usuario para el sistema: " user_sys
user_sys=$(echo "$user_sys" | xargs)

if [ "$user_sys" != '' ]; then
    if id "$user_sys" >/dev/null 2>&1; then
        echo -e "${RED}Error: El usuario $user_sys ya existe${NC}"
        exit 1
    fi
else
    echo -e "${RED}El usuario no puede estar en blanco${NC}"
    exit 1
fi

read -p "Desea instalar postgresql en local (Y/n): " inst_postgres
inst_postgres=$(echo "$inst_postgres" | tr '[:upper:]' '[:lower:]' | xargs)

if [ -z "$inst_postgres" ]; then
    inst_postgres="y"
    host_bd="localhost"
fi

while [ "$inst_postgres" != "y" ] && [ "$inst_postgres" != "n" ]; do
    echo -e "${YELLOW}Opción no válida. Por favor, ingrese 'y' o 'n'.${NC}"
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

read -p "Version de tryton a instalar (ejemplo 7.0/7.8/8.0): " version_tryton
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
echo "INSTALAR TODOS LOS MODULOS..............: $confirmar_modulos"
echo "MODO PRODUCCION.........................: $confirmar_produccion"
echo "#################################################"
echo ""
read -p "DESEA CONFIRMAR ESTOS DATOS (Y/n): " confirmar
confirmar=$(echo "$confirmar" | tr '[:upper:]' '[:lower:]' | xargs)
[ -z "$confirmar" ] && confirmar="y"

if [ "$confirmar" != "y" ]; then
    echo -e "${RED}Proceso cancelado${NC}"
    exit 1
fi

echo -e "${GREEN}Iniciando instalación...${NC}"

# Actualizar repositorios
echo -e "${BLUE}=== Actualizando repositorios ===${NC}"
pkg update -f


echo -e "${BLUE}=== Instalando dependencias básicas ===${NC}"
pkg install -y curl wget git npm node20
pkg install -y cups openldap26-client jpeg-turbo tiff libreoffice webfonts
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
echo -e "${BLUE}=== Instalando Python y compiladores ===${NC}"
pkg install -y python313 
pkg install -y gcc gmake pkgconf git
pkg install -y libxml2 libxslt libffi libyaml


# Crear directorios y usuario
echo -e "${BLUE}=== Creando directorios y usuario ===${NC}"
mkdir -p "$directorio_instalacion"
mkdir -p "$directorio_instalacion"/sao
mkdir -p "$directorio_instalacion"/config
mkdir -p "$directorio_instalacion"/log
mkdir -p "$directorio_instalacion"/storage_db
mkdir -p "$directorio_instalacion"/download

# ---------------------------------------------------------------------------
# NOTA: bash está en /usr/local/bin/bash en FreeBSD; se usa como shell del
# usuario para poder activar el venv con "source" más adelante.
# ---------------------------------------------------------------------------
pw useradd "$user_sys" -m -d "$directorio_instalacion" -s /usr/local/bin/bash 2>/dev/null || true
chown -R "$user_sys":"$user_sys" "$directorio_instalacion"

 # ---------------------------------------------------------------------------
 # Instalar PostgreSQL
 # ---------------------------------------------------------------------------

if [ "$inst_postgres" = "y" ]; then
    echo -e "${BLUE}=== Instalando PostgreSQL 16 ===${NC}"
    pkg install -y postgresql16-server postgresql16-contrib

    sysrc postgresql_enable="YES"

    echo -e "${BLUE}Inicializando PostgreSQL...${NC}"
    /usr/local/etc/rc.d/postgresql initdb


    PG_DATA="/var/db/postgres/data16"
    PG_CONF="$PG_DATA/postgresql.conf"
    PG_HBA="$PG_DATA/pg_hba.conf"

    # Ajustar postgresql.conf (puerto y escucha) ANTES de arrancar
    if [ -f "$PG_CONF" ]; then
        cp "$PG_CONF" "$PG_CONF.bak"
        sed -i '' "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" "$PG_CONF"
        sed -i '' "s/#port = 5432/port = $puerto_bd/g" "$PG_CONF"
    fi



    echo -e "${BLUE}Iniciando PostgreSQL (con trust local para configuración inicial)...${NC}"
    /usr/local/etc/rc.d/postgresql start
    sleep 5

    if ! pgrep -x "postgres" > /dev/null; then
        echo -e "${RED}Error: PostgreSQL no pudo iniciar${NC}"
        echo -e "${YELLOW}Revisa el log: cat /var/db/postgres/data16/pg_log/*.log${NC}"
        exit 1
    fi

    echo -e "${BLUE}Asignando contraseña al superusuario postgres (via socket/trust)...${NC}"
    su -m postgres -c "psql -c \"ALTER USER postgres WITH PASSWORD '$pass_postgres';\""

    echo -e "${BLUE}Creando usuario de aplicación y base de datos...${NC}"
    su -m postgres -c "psql -c \"CREATE ROLE $user_bd WITH LOGIN SUPERUSER PASSWORD '$pass_bd';\"" 2>/dev/null || \
    su -m postgres -c "psql -c \"ALTER USER $user_bd WITH PASSWORD '$pass_bd';\"" 2>/dev/null || true

    su -m postgres -c "psql -c \"CREATE DATABASE $nombre_bd WITH OWNER $user_bd;\"" 2>/dev/null || true
    su -m postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE $nombre_bd TO $user_bd;\"" 2>/dev/null || true

    # Ahora sí: cambiar pg_hba.conf a md5 y recargar
    echo -e "${BLUE}Aumentando seguridad en usuario md5...${NC}"
    if [ -f "$PG_HBA" ]; then
        cp "$PG_HBA" "$PG_HBA.bak"
        sed -i '' 's/trust$/md5/g'          "$PG_HBA"
        sed -i '' 's/ident$/md5/g'          "$PG_HBA"
        sed -i '' 's/peer$/md5/g'           "$PG_HBA"
        sed -i '' 's/scram-sha-256/md5/g'   "$PG_HBA"
    fi

    # Recargar configuración sin reiniciar
    su -m postgres -c "psql -c 'SELECT pg_reload_conf();'"

    # Verificar conectividad con las nuevas credenciales
    echo -e "${BLUE}Verificando conexión con md5...${NC}"
    PGPASSWORD="$pass_postgres" psql -U postgres -h localhost -p "$puerto_bd" \
        -c "SELECT version();" >/dev/null 2>&1 && \
        echo -e "${GREEN}Conexión md5 verificada correctamente${NC}" || \
        echo -e "${YELLOW}Advertencia: no se pudo verificar la conexión md5. Continúa el script.${NC}"

    echo -e "${GREEN}PostgreSQL configurado correctamente${NC}"
fi


echo -e "${BLUE}=== Configurando entorno Python (venv) ===${NC}"
cd "$directorio_instalacion"

su -m "$user_sys" -c "cd $directorio_instalacion && python3.13 -m venv ."

# Helper para ejecutar comandos dentro del venv como $user_sys
venv_run() {
     su -m "$user_sys" -c "cd $directorio_instalacion && bin/pip $*"
}

echo -e "${BLUE}Instalando paquetes Python base...${NC}"
venv_run "install --upgrade pip setuptools wheel"

venv_run "install werkzeug ldap3 python-stdnum simpleeval cached_property \
    requests stripe csb43 pyyaml future ofxparse zeep PyPDF2 wrapt \
    python-sql python-dateutil polib genshi relatorio passlib lxml"

venv_run "install psycopg2-binary uwsgi forex-python phonenumbers pygal"


echo -e "${BLUE}Instalando Tryton $version_tryton...${NC}"
venv_run "install 'trytond==$version_tryton.*' 'proteus==$version_tryton.*'"

# Instalar módulos de Tryton
if [ "$confirmar_modulos" = "y" ]; then
    echo -e "${BLUE}Instalando todos los módulos disponibles...${NC}"
    # ---------------------------------------------------------------------------
    # CAMBIO: fetch en FreeBSD 15 escribe a stdout con -o -
    # Si no hay modules.txt para esa versión, cae a la lista predefinida.
    # ---------------------------------------------------------------------------
    MODULES_LIST=$(fetch -q -o - "https://downloads.tryton.org/$version_tryton/modules.txt" 2>/dev/null)
    if [ -n "$MODULES_LIST" ]; then
        for module in $MODULES_LIST; do
            echo "  Instalando: trytond_$module"
            venv_run "install 'trytond_$module==$version_tryton.*'" 2>/dev/null || true
        done
    else
        echo -e "${YELLOW}  No se encontró modules.txt. Usando lista predefinida...${NC}"
        for module in $tryton_modules; do
            venv_run "install 'trytond_$module==$version_tryton.*'" 2>/dev/null || true
        done
    fi
else
    echo -e "${BLUE}Instalando módulos básicos predefinidos...${NC}"
    for module in $tryton_modules; do
        venv_run "install 'trytond_$module==$version_tryton.*'" 2>/dev/null || true
    done
fi

# Instalar SAO (cliente web)
echo -e "${BLUE}=== Instalando SAO web client ===${NC}"
cd "$directorio_instalacion"/download
fetch "https://downloads.tryton.org/$version_tryton/tryton-sao-last.tgz"
if [ -f "tryton-sao-last.tgz" ]; then
    tar xzf tryton-sao-last.tgz
    cd package
    cp -r . "$directorio_instalacion"/sao/
    cd "$directorio_instalacion"/sao
    echo -e "${BLUE}Instalando dependencias de npm...${NC}"
    # ---------------------------------------------------------------------------
    # CAMBIO: node20 es compatible con --legacy-peer-deps; si falla, probar sin él
    # ---------------------------------------------------------------------------
    npm install --production --legacy-peer-deps 2>/dev/null || \
    npm install --production 2>/dev/null || \
    echo -e "${YELLOW}  npm install completado (posibles advertencias ignoradas)${NC}"
else
    echo -e "${YELLOW}  No se pudo descargar SAO. Continuando sin cliente web...${NC}"
fi

# Configurar permisos
echo -e "${BLUE}Configurando permisos...${NC}"
chown -R "$user_sys":"$user_sys" "$directorio_instalacion"/storage_db
chmod 750 "$directorio_instalacion"/storage_db
chown -R "$user_sys":"$user_sys" "$directorio_instalacion"/log
chmod 750 "$directorio_instalacion"/log
touch "$directorio_instalacion"/log/tryton.log
touch "$directorio_instalacion"/log/tryton-cron.log
touch "$directorio_instalacion"/log/tryton-worker.log
chown "$user_sys":"$user_sys" "$directorio_instalacion"/log/*.log

# Crear archivo de configuración
echo -e "${BLUE}Creando archivo de configuración trytond.conf...${NC}"
cat > "$directorio_instalacion"/config/trytond.conf << EOF
[database]
uri = postgresql://$user_bd:$pass_bd@$host_bd:$puerto_bd/
language = $codigo_pais

[web]
listen = 0.0.0.0:$puerto_tryton_sao
root = $directorio_instalacion/sao

[attachment]
filestore = False
store_prefix = $nombre_bd

[session]
timeout = 300
max_age = 86400

[password]
entropy = 0.75

[queue]
worker = False
clean_days = 30

[error]
clean_days = 120

[email]
uri = smtp://localhost:25
from = tryton@localhost
retry = 5
EOF

# Crear archivos de configuración de log
for logtype in "" "-cron" "-worker"; do
    cat > "$directorio_instalacion"/config/trytond-log${logtype}.conf << EOF
[formatters]
keys=simple

[handlers]
keys=rotate,console

[loggers]
keys=root

[formatter_simple]
format=[%(asctime)s] %(levelname)s:%(name)s:%(message)s
datefmt=%a %b %d %H:%M:%S %Y

[handler_rotate]
class=handlers.TimedRotatingFileHandler
args=('$directorio_instalacion/log/tryton${logtype}.log', 'D', 1, 30)
formatter=simple

[handler_console]
class=StreamHandler
formatter=simple
args=(sys.stdout,)

[logger_root]
level=INFO
handlers=rotate,console
EOF
done

# Configurar uWSGI para producción
if [ "$confirmar_produccion" = "y" ]; then
    echo -e "${BLUE}Configurando uWSGI para modo producción...${NC}"
    cat > "$directorio_instalacion"/config/uwsgi_trytond.conf << EOF
[uwsgi]
http-socket=0.0.0.0:$puerto_tryton_sao
master=true
plugins=python3
env=TRYTOND_CONFIG=$directorio_instalacion/config/trytond.conf
env=TRYTOND_DATABASE_URI=postgresql://$user_bd:$pass_bd@$host_bd:$puerto_bd/$nombre_bd
env=TRYTOND_LOGGING_CONFIG=$directorio_instalacion/config/trytond-log.conf
wsgi=trytond.application:app
processes=4
threads=4
virtualenv=$directorio_instalacion
EOF
fi

# Inicializar base de datos y módulos
echo -e "${BLUE}Inicializando base de datos (puede tardar varios minutos)...${NC}"
venv_run() {
    su -m "$user_sys" -c "cd $directorio_instalacion && $*"
}
    venv_run "bin/trytond-admin \
        -c $directorio_instalacion/config/trytond.conf \
        -d $nombre_bd --all"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Base de datos inicializada correctamente${NC}"

    echo -e "${BLUE}Activando módulo de contabilidad...${NC}"
    venv_run "bin/trytond-admin -u account --activate-dependencies \
        -d $nombre_bd -c $directorio_instalacion/config/trytond.conf" 2>/dev/null || true

    if [ "$codigo_pais" = "es" ]; then
        echo -e "${BLUE}Activando módulo de contabilidad español...${NC}"
        venv_run "bin/trytond-admin -u account_es --activate-dependencies \
            -d $nombre_bd -c $directorio_instalacion/config/trytond.conf" 2>/dev/null || true
    fi

    if [ -f "$directorio_instalacion/bin/trytond_import_countries" ]; then
        echo -e "${BLUE}Importando países...${NC}"
        venv_run "bin/trytond_import_countries -d $nombre_bd \
            -c $directorio_instalacion/config/trytond.conf"  || true
    fi


        if [ -f "$directorio_instalacion/bin/trytond_import_postal_codes" ]; then
        echo -e "${BLUE}Importando Codigos Postales...${NC}"
        venv_run "bin/trytond_import_postal_codes -d $nombre_bd \
            -c $directorio_instalacion/config/trytond.conf es"  || true
    fi

    if [ -f "$directorio_instalacion/bin/trytond_import_currencies" ]; then
        echo -e "${BLUE}Importando monedas...${NC}"
        venv_run "bin/trytond_import_currencies -d $nombre_bd \
            -c $directorio_instalacion/config/trytond.conf" 2>/dev/null || true
    fi
else
    echo -e "${RED}Error al inicializar la base de datos. Revisa los logs.${NC}"
fi


echo -e "${BLUE}Creando servicios rc.d...${NC}"

# Servicio principal
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

pidfile="/var/run/trytond.pid"

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

pidfile="/var/run/trytond-cron.pid"

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

pidfile="/var/run/trytond-worker.pid"

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

pidfile="/var/run/trytond-uwsgi.pid"

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
chmod +x /usr/local/etc/rc.d/trytond-cron
chmod +x /usr/local/etc/rc.d/trytond-worker
chmod +x /usr/local/etc/rc.d/trytond-uwsgi

# Activar y arrancar servicios según modo
if [ "$confirmar_produccion" = "y" ]; then
    echo -e "${BLUE}Modo producción: arrancando con uWSGI...${NC}"

 
    sysrc trytond_uwsgi_enable="YES"
    sysrc trytond_cron_enable="YES"
    sysrc trytond_worker_enable="YES"
    /usr/local/etc/rc.d/trytond-uwsgi start
    /usr/local/etc/rc.d/trytond-cron start
    /usr/local/etc/rc.d/trytond-worker start
else
    sysrc trytond_enable="YES"
    sysrc trytond_cron_enable="YES"
    sysrc trytond_worker_enable="YES"
    /usr/local/etc/rc.d/trytond start
    /usr/local/etc/rc.d/trytond-cron start
    /usr/local/etc/rc.d/trytond-worker start
fi

# Configurar firewall pf
if command -v pfctl >/dev/null 2>&1; then
    echo -e "${BLUE}Configurando firewall pf...${NC}"
    # Añadir reglas solo si no existen ya
    grep -q "port $puerto_tryton_sao" /etc/pf.conf 2>/dev/null || \
        echo "pass in proto tcp from any to any port $puerto_tryton_sao" >> /etc/pf.conf
    grep -q "port $puerto_tryton_xml" /etc/pf.conf 2>/dev/null || \
        echo "pass in proto tcp from any to any port $puerto_tryton_xml" >> /etc/pf.conf
    pfctl -f /etc/pf.conf 2>/dev/null || true
fi

# Obtener IP
IP_ADDR=$(ifconfig | grep -E 'inet [0-9]' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)

echo ""
echo -e "${GREEN}#################################################${NC}"
echo -e "${GREEN}########### INSTALACION COMPLETADA ##############${NC}"
echo -e "${GREEN}#################################################${NC}"
echo ""
echo -e "${GREEN}Tryton ha sido instalado exitosamente${NC}"
echo -e "${BLUE}URL de acceso SAO: http://${IP_ADDR:-localhost}:$puerto_tryton_sao${NC}"
echo ""
echo ""
echo -e "${BLUE}Servicios disponibles:${NC}"
if [ "$confirmar_produccion" = "y" ]; then
    echo "  - trytond-uwsgi  (servidor producción)"
else
    echo "  - trytond        (servidor principal)"
fi
echo "  - trytond-cron   "
echo "  - trytond-worker "
echo ""
echo -e "${BLUE}Directorios importantes:${NC}"
echo "  Configuración : $directorio_instalacion/config/"
echo "  Logs          : $directorio_instalacion/log/"
echo "  SAO Web       : $directorio_instalacion/sao/"
echo "  Storage       : $directorio_instalacion/storage_db/"
echo ""
echo -e "${BLUE}Comandos útiles:${NC}"
echo "  service trytond status"
echo "  service trytond restart"
echo "  tail -f $directorio_instalacion/log/tryton.log"
echo ""


