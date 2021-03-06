#!/bin/sh

for i in "$@"
do
case $i in
    --hostip=*)
    HOSTIP="${i#*=}"
    shift # past argument=value
    ;;
    --network=*)
    NETWORK="${i#*=}"
    shift # past argument=value
    ;;
    --port=*)
    PORT="${i#*=}"
    shift # past argument=value
    ;;
    --force)
    FORCE="y"
    shift # past argument=value
    ;;
    --vip=*)
    VIP_IP="${i#*=}"
    shift # past argument=value
    ;;
    --endpoint=*)
    DCS_ENDPOINT="${i#*=}"
    shift # past argument=value
    ;;
    *)
       # unknown option
    ;;
esac
done

if [ -z "$2" ];
then
    echo "Usage: pg_creatconfig_patroni [options] <version> <cluster name>"
    exit 1
else
    VERSION=$1
    echo $VERSION | egrep -q '^[[:digit:]]+\.?[[:digit:]]+$'
    if [ $? -ne 0 ]; then
	echo "Error: invalid version ${VERSION}"
	exit 1
    fi
    if [ ! -f /usr/lib/postgresql/${VERSION}/bin/initdb ]; then
	echo "Error: no initdb program for version ${VERSION} found"
	exit 1
    fi
fi

if [ -z "$2" ];
then
    echo "Usage: pg_creatconfig_patroni [options] <version> <cluster name>"
    exit 1
else
    CLUSTER=$2
fi

if [ -z "$PORT" ]; then
    # try to guess next free port
    PORT=$(($(pg_lsclusters -h | awk '{print $3}' | sort -n | tail -1) + 1))
    if [ "$PORT" -eq 1 ]; then
	# No cluster exists yet, use default port
	PORT=5432
    fi
else
    # validate specified port
    pg_lsclusters | awk '{print $3}' | grep -q $PORT && echo "Port $PORT already in use" && exit 1
fi

# determine API port (default is 8008) by incrementing for each additional
# Postgres port.  2576 is 8008 - 5432.
API_PORT=$((2576+$PORT))

# check DCS configuration
if [ ! -f /etc/patroni/dcs.yml ]; then
    echo "DCS not configured yet, edit /etc/patroni/dcs.yml"
    exit 1
fi
grep -v "^#" /etc/patroni/dcs.yml | grep -v "^$" > /dev/null 2>&1
if [ $? != 0 ]; then
    echo "DCS not configured yet, edit /etc/patroni/dcs.yml"
    exit 1
fi
DCS_CONFIG="$(egrep -v '^[[:space:]]*$|^ *#' /etc/patroni/dcs.yml | sed -e ':a;N;$!ba;s/\n/\\n/g' -e 's/\$/\\$/g')"

# check vip configuration
if [ -n "$VIP_IP" ]; then
    VIP_FILE=/etc/patroni/${VERSION}-${CLUSTER}.vip
    if [ -f $VIP_FILE -a -z "$FORCE" ]; then
        echo "VIP configuration file already exists"
        exit 1
    else
        rm -f $VIP_FILE
        touch $VIP_FILE
    fi
    if [ ! -e /etc/patroni/vip.in ]; then
        echo "VIP template /etc/patroni/vip.in does not exist, cannot write VIP file"
        exit 1
    fi
    if [ $(grep -q LISTEN_VIP /etc/patroni/config.yml.in) ]; then
        echo "Patroni configuration template does not have @LISTEN_VIP@ tag"
        echo "Postgres will not be able to bind to the VIP $VIP_IP."
        exit 1
    fi
    VIP_IFACE="$(ip -4 route get 8.8.8.8 | grep ^8.8.8.8 | sed -e s/.*dev.// -e s/\ .*//)"
    if [ -z "$VIP_IFACE" ]; then
        echo "Network interface could not be determined, cannot write VIP file"
        exit 1
    fi
    VIP_MASK="$(ip -o -f inet addr show $VIP_IFACE | awk '{print $4}' | sed -e 's/.*\///' | uniq)"
    if [ -z "$VIP_MASK" ]; then
        echo "Netmask could not be determined, cannot write VIP file"
        exit 1
    fi
    VIP_KEY="/postgresql-common/${VERSION}-${CLUSTER}/leader"
    DCS_TYPE="$(egrep -v '^[[:space:]]*$|^ *#' /etc/patroni/dcs.yml | egrep '(etcd|consul|zookeeper)' | sed s/:.*//)"
    if [ -z "$DCS_TYPE" ]; then
        echo "DCS type could not be determined from /etc/patroni/dcs.yml, cannot write VIP file"
	exit 1
    fi
    if [ -z "$DCS_ENDPOINT" ]; then
        DCS_ENDPOINT="$(egrep -v '^[[:space:]]*$|^ *#' /etc/patroni/dcs.yml | egrep '(host|-)' | egrep '[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+' | sed -r -e s/.*host:// -e s/-// -e 's/ //g' -e 's/^([0-9])/http:\/\/\1/')"
        if [ -z "$DCS_ENDPOINT" ]; then
            echo "DCS endpoint URL could not be determined from /etc/patroni/dcs.yml and --endpoint not provided, cannot write VIP file"
	    exit 1
        fi
        if [ $(echo "$DCS_ENDPOINT" | wc -l) != 1 ]; then
            echo "DCS endpoint URL could not be determined from /etc/patroni/dcs.yml and --endpoint not provided, cannot write VIP file"
            exit 1
        fi
    fi
    if ! $(echo "$DCS_ENDPOINT" | egrep -q '^http.*://[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+:[[:digit:]]+$'); then
        echo "DCS endpoint URL not in 'http://1.2.3.4:1234' format, cannot write VIP file"
        exit 1
    fi
    LISTEN_VIP=",$VIP_IP"
else
    LISTEN_VIP=
fi

CONFIG_FILE=/etc/patroni/${VERSION}-${CLUSTER}.yml

if [ -f $CONFIG_FILE -a -z "$FORCE" ]; then
    echo "Patroni configuration file already exists"
    exit 1
else
    rm -f $CONFIG_FILE
    touch $CONFIG_FILE
fi

HOSTNAME=$(hostname)

# set default ipv4 address in case it was not provided
if [ -z "$HOSTIP" ]; then
    if [ -x /bin/ip ]; then
        HOSTIP=$(/bin/ip -4 route get 8.8.8.8 | grep ^8.8.8.8 | sed -e s/.*src.// -e s/\ .*//g)
    else
        echo "iproute2 package missing, cannot determine host ip addresss and --hostip is not set"
        rm -f $CONFIG_FILE
        exit 1
    fi
fi

if [ -z "$NETWORK" ]; then
    if [ -x /bin/ip ]; then
        NETWORK=$(/bin/ip -4 route get 8.8.8.8 | grep ^8.8.8.8 | sed -e s/.*src.// -e s/\ .*//g -e s/\.[0-9]*$/.0/)/24
    else
        echo "iproute2 package missing, cannot determine network and --network is not set"
        rm -f $CONFIG_FILE
        exit 1
    fi
fi

# add remaining patroni configuration from template
cat /etc/patroni/config.yml.in |		\
    sed -e "s/@VERSION@/${VERSION}/g"		\
        -e "s/@CLUSTER@/${CLUSTER}/g"		\
        -e "s/@HOSTNAME@/${HOSTNAME}/g"		\
        -e "s/@HOSTIP@/${HOSTIP}/g"		\
        -e "s/@LISTEN_VIP@/${LISTEN_VIP}/g"	\
        -e "s#@NETWORK@#${NETWORK}#g"		\
        -e "s/@API_PORT@/${API_PORT}/g"		\
        -e "s/@PORT@/${PORT}/g"			\
        -e "s/@DCS_CONFIG@/${DCS_CONFIG}/g"	\
>> $CONFIG_FILE

# write vip configuration, if requested
if [ -n "$VIP_IP" ]; then
    cat /etc/patroni/vip.in |				\
        sed -e "s/@VIP_IP@/${VIP_IP}/g"			\
            -e "s/@VIP_MASK@/${VIP_MASK}/g"		\
            -e "s/@VIP_IFACE@/${VIP_IFACE}/g"		\
            -e "s#@VIP_KEY@#${VIP_KEY}#g"		\
            -e "s/@VIP_HOST@/${HOSTNAME}/g"		\
            -e "s/@VIP_TYPE@/${DCS_TYPE}/g"		\
            -e "s#@VIP_ENDPOINT@#${DCS_ENDPOINT}#g"	\
    >> $VIP_FILE
fi

# Set permissions
chown postgres:postgres $CONFIG_FILE
chmod 660 $CONFIG_FILE
