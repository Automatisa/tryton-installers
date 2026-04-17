#!/bin/bash

postgres_act(){
    if systemctl is-active --quiet postgresql; then
        echo "true"
    else
        echo "false"
    fi
}

existe_programa(){ 
    which "$1" >/dev/null 2>&1 && echo "si" || echo "no"
}

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
account
account_credit_limit
account_invoice
account_invoice_stock
account_product
account_payment_clearing
account_invoice_stock
account_payment
account_payment_clearing
account_move_line_grouping 
account_invoice_secondary_unit
sale
sale_opportunity
sale_product_customer
sale_credit_limit
sale_payment
sale_invoice_grouping
sale_invoice_date
sale_discount
sale_supply
sale_stock_quantity
sale_product_quantity
purchase
purchase_history
bank
"

clear

echo "#################################################"
echo "#############INTALACION DE TRYTON################"
echo "#################################################"
echo ""
echo ""

if [ $EUID != 0 ]; then 
    echo "Este script necesita ser ejecutado como superusuario"
    exit 1
fi

# Solicitar datos de configuración
read -rp "Usuario para el sistema: " user_sys
user_sys="${user_sys#"${user_sys%%[![:space:]]*}"}"
user_sys="${user_sys%"${user_sys##*[![:space:]]}"}"

if [ "$user_sys" != '' ]; then
    if id "$user_sys" &>/dev/null; then
        echo "Error: El usuario $user_sys ya existe"
        exit
    fi
else
    echo "El usuario no puede estar en blanco"
    exit
fi

read -rp "Desea instalar postgresql en local (Y/n): " inst_postgres
inst_postgres=${inst_postgres,,}
inst_postgres="${inst_postgres%"${inst_postgres##*[![:space:]]}"}"
inst_postgres="${inst_postgres#"${inst_postgres%%[![:space:]]}"}"

if [ -z "$inst_postgres" ]; then
    inst_postgres="y"
    host_bd="localhost"
fi

while [[ "$inst_postgres" != "y" && "$inst_postgres" != "n" ]]; do
    echo "Opción no válida. Por favor, ingrese 'y' o 'n'."
    read -rp "Desea instalar postgresql en local (Y/n): " inst_postgres
    inst_postgres=${inst_postgres,,}
    if [ -z "$inst_postgres" ]; then
        inst_postgres="y"
        host_bd="localhost"
    fi
done

if [ "$inst_postgres" = "y" ]; then
    host_bd="localhost"
    # ► NUEVO: pedir contraseña para el superusuario postgres
    read -s -rp "Password para el superusuario postgres: " pass_postgres
    echo ""
    pass_postgres="${pass_postgres#"${pass_postgres%%[![:space:]]*}"}"
    pass_postgres="${pass_postgres%"${pass_postgres##*[![:space:]]}"}"
fi

read -rp "Version de tryton a instalar (ejemplo 6.0/6.2/7.0 etc): " version_tryton
version_tryton="${version_tryton#"${version_tryton%%[![:space:]]*}"}"
version_tryton="${version_tryton%"${version_tryton##*[![:space:]]}"}"

read -rp "Codigo pais (ejemplo: es): " codigo_pais
codigo_pais="${codigo_pais#"${codigo_pais%%[![:space:]]*}"}"
codigo_pais="${codigo_pais%"${codigo_pais##*[![:space:]]}"}"

read -rp "Nombre base de datos: " nombre_bd
nombre_bd="${nombre_bd#"${nombre_bd%%[![:space:]]*}"}"
nombre_bd="${nombre_bd%"${nombre_bd##*[![:space:]]}"}"

read -rp "Directorio para instalación tryton (defecto /opt/tryton): " directorio_instalacion
directorio_instalacion="${directorio_instalacion#"${directorio_instalacion%%[![:space:]]*}"}"
directorio_instalacion="${directorio_instalacion%"${directorio_instalacion##*[![:space:]]}"}"

if [ -z "$directorio_instalacion" ]; then
    directorio_instalacion="/opt/tryton"
fi

if [ "$inst_postgres" == "n" ]; then
    read -rp "Host base de datos: " host_bd
    host_bd="${host_bd#"${host_bd%%[![:space:]]*}"}"
    host_bd="${host_bd%"${host_bd##*[![:space:]]}"}" 
fi

read -rp "Puerto de conexion SAO tryton (default:8000): " puerto_tryton_sao
puerto_tryton_sao="${puerto_tryton_sao#"${puerto_tryton_sao%%[![:space:]]*}"}"
puerto_tryton_sao="${puerto_tryton_sao%"${puerto_tryton_sao##*[![:space:]]}"}"
[ -z "$puerto_tryton_sao" ] && puerto_tryton_sao="8000"

read -rp "Puerto de conexion xmlrpc tryton (default:8080): " puerto_tryton_xml
puerto_tryton_xml="${puerto_tryton_xml#"${puerto_tryton_xml%%[![:space:]]*}"}"
puerto_tryton_xml="${puerto_tryton_xml%"${puerto_tryton_xml##*[![:space:]]}"}"
[ -z "$puerto_tryton_xml" ] && puerto_tryton_xml="8080"

read -rp "Puerto base de datos (default:5432): " puerto_bd
puerto_bd="${puerto_bd#"${puerto_bd%%[![:space:]]*}"}"
puerto_bd="${puerto_bd%"${puerto_bd##*[![:space:]]}"}"
[ -z "$puerto_bd" ] && puerto_bd="5432"

read -rp "Usuario bd: " user_bd
user_bd="${user_bd#"${user_bd%%[![:space:]]*}"}"
user_bd="${user_bd%"${user_bd##*[![:space:]]}"}"

read -s -rp "Password base de datos: " pass_bd
echo ""
pass_bd="${pass_bd#"${pass_bd%%[![:space:]]*}"}"
pass_bd="${pass_bd%"${pass_bd##*[![:space:]]}"}"

read -rp "Desea instalar todos los modulos (Y/n): " confirmar_modulos
confirmar_modulos=${confirmar_modulos,,}
[ -z "$confirmar_modulos" ] && confirmar_modulos="y"

while [[ "$confirmar_modulos" != "y" && "$confirmar_modulos" != "n" ]]; do
    read -rp "Desea descargar todos los modulos (Y/n): " confirmar_modulos
    confirmar_modulos=${confirmar_modulos,,}
    [ -z "$confirmar_modulos" ] && confirmar_modulos="y"
done

read -rp "Quiere ponerlo en modo produccion (Y/n): " confirmar_produccion
confirmar_produccion=${confirmar_produccion,,}
[ -z "$confirmar_produccion" ] && confirmar_produccion="y"

while [[ "$confirmar_produccion" != "y" && "$confirmar_produccion" != "n" ]]; do
    read -rp "Quiere ponerlo en modo produccion (Y/n): " confirmar_produccion
    confirmar_produccion=${confirmar_produccion,,}
    [ -z "$confirmar_produccion" ] && confirmar_produccion="y"
done

# Mostrar resumen
clear
echo "#################################################"
echo "#########DATOS PARA LA INSTALACION DE TRYTON######"
echo "#################################################"
echo ""
echo "INSTALAR POSTGRES LOCALHOST............:$inst_postgres"
echo "VERSION DE TRYTON.......................:$version_tryton"
echo "CODIGO DE PAIS..........................:$codigo_pais"
echo "NOMBRE BASE DE DATOS....................:$nombre_bd"
echo "DIRECTORIO DE INSTALACION...............:$directorio_instalacion"
echo "PUERTO DE LA BASE DE DATOS..............:$puerto_bd"
echo "PUERTO SAO DE TRYTON....................:$puerto_tryton_sao"
echo "PUERTO XMLRPC DE TRYTON.................:$puerto_tryton_xml"
echo "HOST DE LA BASE DE DATOS................:$host_bd"
echo "USUARIO DE LA BASE DE DATOS.............:$user_bd"
echo "USUARIO PARA EL SISTEMA.................:$user_sys"
echo "#################################################"
echo ""
read -rp "DESEA CONFIRMAR ESTOS DATOS (Y/n): " confirmar
confirmar=${confirmar,,}
[ -z "$confirmar" ] && confirmar="y"

if [ "$confirmar" != "y" ]; then
    echo "Proceso cancelado"
    exit
fi

# Iniciar instalación
echo "Iniciando instalación..."

# Actualizar sistema
apt update -y

# Instalar dependencias básicas primero (incluyendo curl y npm)
echo "Instalando dependencias básicas..."
apt install -y curl wget git npm

# Instalar Python
echo "Instalando Python..."
apt install -y python3.13 python3.13-dev

# Crear usuario y directorios
useradd -m -d "$directorio_instalacion" -U -r -s /bin/bash "$user_sys" || exit
mkdir -p "$directorio_instalacion"/sao
mkdir -p "$directorio_instalacion"/config
mkdir -p "$directorio_instalacion"/log
mkdir -p "$directorio_instalacion"/storage_db

# Instalar dependencias del sistema
echo "Instalando dependencias del sistema..."
apt install -y  \
    cups libcups2-dev gcc g++ make nano \
    python3-lxml python3-ldap \
    libpq-dev libldap2-dev libsasl2-dev \
    libffi-dev fontconfig libx11-6 libxext6 libxrender1 \
    xfonts-75dpi xfonts-base libxml2-dev libxmlsec1-dev \
    libxmlsec1-openssl libltdl-dev libcairo2-dev \
    libcairo-gobject2 gir1.2-cairo-1.0 libgirepository1.0-dev \
    build-essential libssl-dev libjpeg-dev zlib1g-dev pkg-config \
    libxml2-dev libxslt1-dev libreoffice-nogui

# Instalar PostgreSQL si es necesario
if [ "$inst_postgres" = "y" ]; then
    if ! command -v psql &>/dev/null; then
        echo "Instalando PostgreSQL..."
        apt install -y postgresql postgresql-contrib

        postgresql_conf=$(find /etc/postgresql -name postgresql.conf 2>/dev/null | head -n 1)
        if [ -n "$postgresql_conf" ]; then
            cp "$postgresql_conf" "$postgresql_conf.bak"
            sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" "$postgresql_conf"
            sed -i "s/#port = 5432/port = $puerto_bd/g" "$postgresql_conf"

            # ► NUEVO: establecer contraseña del superusuario postgres ANTES de cambiar
            #          pg_hba.conf, mientras aún está activa la autenticación peer/socket
            echo "Estableciendo contraseña del superusuario postgres..."
            runuser -u postgres -- psql -c "ALTER USER postgres PASSWORD '$pass_postgres';"

            # Ahora sí cambiamos pg_hba.conf a md5
            pg_hba_conf=$(find /etc/postgresql -name pg_hba.conf 2>/dev/null | head -n 1)
            cp "$pg_hba_conf" "$pg_hba_conf.bak"
            sed -i 's/ident$/md5/g' "$pg_hba_conf"
            sed -i 's/peer$/md5/g' "$pg_hba_conf"
            sed -i 's/scram-sha-256/md5/g' "$pg_hba_conf"

            systemctl restart postgresql
            systemctl enable postgresql
            sleep 3
        fi
    fi

    # ► NUEVO: crear usuario y BD usando PGPASSWORD + conexión TCP (127.0.0.1)
    #          ya que pg_hba.conf ahora exige contraseña en todas las conexiones
    echo "Creando usuario de base de datos..."
    if PGPASSWORD="$pass_postgres" psql -U postgres -h 127.0.0.1 -p "$puerto_bd" \
        -c "CREATE USER $user_bd WITH PASSWORD '$pass_bd';" 2>/dev/null; then
        echo "Usuario $user_bd creado correctamente"
    else
        echo "El usuario $user_bd ya existe o hubo un error"
    fi

    PGPASSWORD="$pass_postgres" psql -U postgres -h 127.0.0.1 -p "$puerto_bd" \
        -c "CREATE DATABASE $nombre_bd WITH OWNER $user_bd;" 2>/dev/null || true

    PGPASSWORD="$pass_postgres" psql -U postgres -h 127.0.0.1 -p "$puerto_bd" \
        -c "GRANT ALL PRIVILEGES ON DATABASE $nombre_bd TO $user_bd;" 2>/dev/null || true

    # Verificar si la base de datos se creó correctamente
    if PGPASSWORD="$pass_postgres" psql -U postgres -h 127.0.0.1 -p "$puerto_bd" \
        -lqt 2>/dev/null | cut -d '|' -f 1 | grep -qw "$nombre_bd"; then
        echo "Base de datos $nombre_bd creada exitosamente"
    else
        echo "Error: No se pudo crear la base de datos $nombre_bd"
    fi
fi

# Configurar entorno Python
cd "$directorio_instalacion" || exit

if command -v python3.11 &>/dev/null; then
    PYTHON_CMD="python3.13"
else
    PYTHON_CMD="python3"
fi

echo "Usando Python: $PYTHON_CMD"

# Crear entorno virtual
$PYTHON_CMD -m venv .
if [ $? -ne 0 ]; then
    echo "Error creando entorno virtual. Instalando python3-venv..."
    $PYTHON_CMD -m venv .
fi

# Activar entorno virtual
source bin/activate

# Actualizar pip
pip install --upgrade pip

# Instalar paquetes Python
echo "Instalando paquetes Python..."
pip install wheel
pip install werkzeug ldap3 python-stdnum simpleeval cached_property requests stripe csb43 febelfin-coda pyyaml future ofxparse zeep PyPDF2 wrapt python-sql python-dateutil polib genshi relatorio passlib
pip install psycopg2-binary
pip install uwsgi
pip install forex-python
pip install phonenumbers 
pip install pygal
pip install "trytond==$version_tryton.*"
pip install "proteus==$version_tryton.*"

# Instalar módulos de Tryton
if [ "$confirmar_modulos" = "y" ]; then
    echo "Descargando todos los módulos..."
    for module in $(curl -L -s https://downloads.tryton.org/"$version_tryton"/modules.txt); do
        echo "Instalando: $module"
        pip install "trytond_$module==$version_tryton.*"
    done
else
    echo "Descargando módulos básicos..."
    for module in $tryton_modules; do
        pip install "trytond_$module==$version_tryton.*"
    done
fi

# Instalar SAO (web client)
echo "Instalando SAO web client..."
mkdir -p "$directorio_instalacion"/sao/download
cd "$directorio_instalacion"/sao/download
wget -q https://downloads.tryton.org/"$version_tryton"/tryton-sao-last.tgz
tar xzf tryton-sao-last.tgz
cd package && cp -r ./ "$directorio_instalacion"/sao/
cd "$directorio_instalacion"/sao
npm install --production --legacy-peer-deps

# storage_db y logs

chown "$user_sys":"$user_sys" "$directorio_instalacion"/storage_db
chmod 750 "$directorio_instalacion"/storage_db

# directorio_instalacion/log/tryton logs del servidor (referenciados en trytond-log*.conf)
chown "$user_sys":"$user_sys" "$directorio_instalacion"/log
chmod 750 "$directorio_instalacion"/log
touch "$directorio_instalacion"/log/{tryton,tryton-cron,tryton-worker}.log
chown "$user_sys":"$user_sys" $directorio_instalacion/log/*.log

# Crear archivo de configuración
cat > "$directorio_instalacion"/config/trytond.conf << EOF
[database]
# URI de conexión a PostgreSQL (sin nombre de BD: trytond lo gestiona por BD activa)
uri = postgresql://$user_bd:$pass_bd@$host_bd:$puerto_bd/
# Directorio raíz del FileStore (adjuntos, avatares, informes almacenados en disco)
# Ruta estándar del sistema, separada del directorio de la aplicación
#path = $directorio_instalacion/storage_db

# Idioma principal para almacenamiento de traducciones en BD
language = $codigo_pais

[web]
# Interfaz web (SAO y API JSON-RPC)
listen = 0.0.0.0:$puerto_tryton_sao
root = $directorio_instalacion/sao

[attachment]
# Almacenar adjuntos en disco (FileStore) en lugar de en la BD — recomendado
filestore = False
# Prefijo de subdirectorio dentro del FileStore para los adjuntos
store_prefix = $nombre_bd

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


EOF

# Crear archivos de log
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

# Crear servicios systemd
cat > /etc/systemd/system/trytond.service << EOF
[Unit]
Description=Tryton Server
After=network.target postgresql.service

[Service]
Type=simple
User=$user_sys
Group=$user_sys
ExecStart=$directorio_instalacion/bin/$PYTHON_CMD $directorio_instalacion/bin/trytond -c $directorio_instalacion/config/trytond.conf --logconf $directorio_instalacion/config/trytond-log.conf -d $nombre_bd
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/trytond-cron.service << EOF
[Unit]
Description=Tryton Cron
After=network.target postgresql.service

[Service]
Type=simple
User=$user_sys
Group=$user_sys
ExecStart=$directorio_instalacion/bin/$PYTHON_CMD $directorio_instalacion/bin/trytond-cron -c $directorio_instalacion/config/trytond.conf --logconf $directorio_instalacion/config/trytond-log-cron.conf -d $nombre_bd
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/trytond-worker.service << EOF
[Unit]
Description=Tryton Worker
After=network.target postgresql.service

[Service]
Type=simple
User=$user_sys
Group=$user_sys
ExecStart=$directorio_instalacion/bin/$PYTHON_CMD $directorio_instalacion/bin/trytond-worker -c $directorio_instalacion/config/trytond.conf --logconf $directorio_instalacion/config/trytond-log-worker.conf -d $nombre_bd
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/trytond-uwsgi.service << EOF
[Unit]
Description=Tryton uWSGI Server
After=network.target postgresql.service

[Service]
Type=simple
User=$user_sys
Group=$user_sys
ExecStart=$directorio_instalacion/bin/uwsgi --ini $directorio_instalacion/config/uwsgi_trytond.conf
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Configurar uwsgi para producción
cat > "$directorio_instalacion"/config/uwsgi_trytond.conf << EOF
[uwsgi]
http-socket=0.0.0.0:$puerto_tryton_sao
master=true
plugins=python3
env=TRYTOND_CONFIG=$directorio_instalacion/config/trytond.conf
# URI completa de PostgreSQL — solo el nombre de BD causaría error de conexión
env=TRYTOND_DATABASE_URI=postgresql://$user_bd:$pass_bd@$host_bd:$puerto_bd/$nombre_bd
env=TRYTOND_LOGGING_CONFIG=$directorio_instalacion/config/trytond-log.conf
wsgi=trytond.application:app
processes=4
threads=4
virtualenv=$directorio_instalacion
EOF

systemctl daemon-reload

# Verificar que los binarios existen antes de continuar
if [ ! -f "$directorio_instalacion/bin/trytond-admin" ]; then
    echo "ERROR: trytond-admin no se instaló correctamente"
    echo "Intentando instalar nuevamente..."
    # El entorno virtual ya está activado desde el paso anterior
    pip install "trytond==$version_tryton.*" --force-reinstall
fi

# Configurar base de datos y módulos
# IMPORTANTE: el entorno virtual debe estar activo (source bin/activate ya ejecutado arriba)
if [ -f "$directorio_instalacion/bin/trytond-admin" ]; then
    echo "Inicializando esquema de base de datos (esto puede tardar varios minutos)..."
    # --all inicializa todas las tablas del esquema Tryton en la BD
    # Sin este paso la BD existe en PostgreSQL pero Tryton no la reconoce
    "$directorio_instalacion/bin/trytond-admin" \
        -c "$directorio_instalacion/config/trytond.conf" \
        -d "$nombre_bd" --all
    
    if [ $? -ne 0 ]; then
        echo "ERROR: trytond-admin falló. Revisa los logs antes de continuar."
        echo "Comando para reintentar manualmente:"
        echo "  source $directorio_instalacion/bin/activate"
        echo "  $directorio_instalacion/bin/trytond-admin -c $directorio_instalacion/config/trytond.conf -d $nombre_bd --all"
        exit 1
    fi

    echo "Activando módulo de contabilidad y dependencias..."
    "$directorio_instalacion/bin/trytond-admin" \
        -u account --activate-dependencies \
        -d "$nombre_bd" \
        -c "$directorio_instalacion/config/trytond.conf"
    
    if [ "$codigo_pais" = "es" ]; then
        echo "Activando módulo de contabilidad español..."
        "$directorio_instalacion/bin/trytond-admin" \
            -u account_es --activate-dependencies \
            -d "$nombre_bd" \
            -c "$directorio_instalacion/config/trytond.conf"
    fi
    
    echo "Importando países, códigos postales y monedas..."
    "$directorio_instalacion/bin/trytond_import_countries" \
        -d "$nombre_bd" -c "$directorio_instalacion/config/trytond.conf"
    "$directorio_instalacion/bin/trytond_import_postal_codes" \
        -d "$nombre_bd" -c "$directorio_instalacion/config/trytond.conf" "$codigo_pais"
    "$directorio_instalacion/bin/trytond_import_currencies" \
        -d "$nombre_bd" -c "$directorio_instalacion/config/trytond.conf"
else
    echo "ADVERTENCIA: trytond-admin no disponible. La configuración de la base de datos debe hacerse manualmente:"
    echo "  source $directorio_instalacion/bin/activate"
    echo "  $directorio_instalacion/bin/trytond-admin -c $directorio_instalacion/config/trytond.conf -d $nombre_bd --all"
fi

# Iniciar servicios
if [ "$confirmar_produccion" = "y" ]; then
    systemctl enable trytond-uwsgi
    systemctl start trytond-uwsgi
    
else
    systemctl enable trytond trytond-cron trytond-worker
    systemctl start trytond trytond-cron trytond-worker
fi

systemctl enable trytond-cron trytond-worker
systemctl start trytond-cron trytond-worker

# Configurar firewall
if command -v ufw &>/dev/null; then
    ufw allow $puerto_tryton_sao/tcp
    ufw allow $puerto_tryton_xml/tcp
    echo "Firewall configurado"
fi

echo ""
echo "#################################################"
echo "########### INSTALACION COMPLETADA ##############"
echo "#################################################"
echo ""
echo "Tryton ha sido instalado exitosamente"
echo "URL de acceso: http://$(hostname -I | awk '{print $1}'):$puerto_tryton_sao"
echo ""
echo "Servicios disponibles:"
if [ "$confirmar_produccion" = "y" ]; then
    echo "- trytond-uwsgi (modo producción)"
else
    echo "- trytond (servidor principal)"
fi
echo "- trytond-cron    (tareas programadas)"
echo "- trytond-worker  (procesamiento en segundo plano)"
echo "###################################################"
echo "  Configuración : $directorio_instalacion/config/"
echo "  Logs          : $directorio_instalacion/log/"
echo "  SAO Web       : $directorio_instalacion/sao/"
echo "  Storage       : $directorio_instalacion/storage_db/"
echo ""
echo "Logs: $directorio_instalacion/log/"
echo "Configuración: $directorio_instalacion/config/"
echo ""
