#!/bin/bash

set -e

# Allow the container to be started with `--user`
if [[ "$1" = 'zkServer.sh' && "$(id -u)" = '0' ]]; then
    chown -R "$ZOO_USER" "$ZOO_DATA_DIR" "$ZOO_DATA_LOG_DIR" "$ZOO_LOG_DIR" "$ZOO_CONF_DIR"
    exec su-exec "$ZOO_USER" "$0" "$@"
fi

# Generate the config only if it doesn't exist
if [[ ! -f "$ZOO_CONF_DIR/zoo.cfg" ]]; then
    CONFIG="$ZOO_CONF_DIR/zoo.cfg"

    echo "dataDir=$ZOO_DATA_DIR" >> "$CONFIG"
    echo "dataLogDir=$ZOO_DATA_LOG_DIR" >> "$CONFIG"

    echo "tickTime=$ZOO_TICK_TIME" >> "$CONFIG"
    echo "initLimit=$ZOO_INIT_LIMIT" >> "$CONFIG"
    echo "syncLimit=$ZOO_SYNC_LIMIT" >> "$CONFIG"

    echo "autopurge.snapRetainCount=$ZOO_AUTOPURGE_SNAPRETAINCOUNT" >> "$CONFIG"
    echo "autopurge.purgeInterval=$ZOO_AUTOPURGE_PURGEINTERVAL" >> "$CONFIG"
    echo "maxClientCnxns=$ZOO_MAX_CLIENT_CNXNS" >> "$CONFIG"
    
    if [[ -z $ZOO_K8S_NAME ]]; then
        echo "standaloneEnabled=$ZOO_STANDALONE_ENABLED" >> "$CONFIG"
    
        if [[ -z $ZOO_SERVERS ]]; then
            ZOO_SERVERS="server.1=localhost:2888:3888;$ZOO_PORT"
        fi
    
        for server in $ZOO_SERVERS; do
            echo "$server" >> "$CONFIG"
        done
    fi
fi

# Write myid only if it doesn't exist
if [[ ! -f "$ZOO_DATA_DIR/myid" ]]; then
    echo "${ZOO_MY_ID:-1}" > "$ZOO_DATA_DIR/myid"
fi

# if k8s statefulset
if [[ -n $ZOO_K8S_NAME ]]; then
    hostname=`hostname`
    index=${hostname##*-}
    expr $index "+" 10 &> /dev/null
    if [[ $? -eq 0 ]];then
        echo "${index}" > "$ZOO_DATA_DIR/myid"
    fi
    if [[ -z "$ZOO_REPLICAS" ]]; then
       ZOO_REPLICAS=3
    fi
    domain=`hostname -d`
    for ((i=0; i<=$ZOO_REPLICAS; i++))
    do
        echo "server.$i=$ZOO_K8S_NAME-$i.$domain:2888:3888" >> "$CONFIG"
    done
fi

exec "$@"
