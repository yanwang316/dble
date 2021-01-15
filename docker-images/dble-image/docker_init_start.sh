#!/bin/sh

echo "dble init&start in docker"

if [ -n "$MASTERS" ] && [ -n "$SLAVES" ] &&  [ -n "$MYSQL_REPLICATION_USER" ] && [ -n "$MYSQL_REPLICATION_PASSWORD" ]; then
      # master:
      masters=(${MASTERS//,/ })
      for M in ${masters[@]}
      do
      mysql -h$M -p3306 -uroot -p123456 \
        -e "CHANGE MASTER TO MASTER_USER='$MYSQL_REPLICATION_USER', MASTER_PASSWORD ='$MYSQL_REPLICATION_PASSWORD' for channel 'group_replication_recovery' ;" \
        -e "SET @@GLOBAL.group_replication_bootstrap_group=1;START GROUP_REPLICATION;SET @@GLOBAL.group_replication_bootstrap_group=0;"
      done

      # slave:
      slaves=(${SLAVES//,/ })
      for S in ${slaves[@]}
      do
      mysql -h$S -p3306 -uroot -p123456 \
        -e "CHANGE MASTER TO MASTER_USER='$MYSQL_REPLICATION_USER', MASTER_PASSWORD ='$MYSQL_REPLICATION_PASSWORD' for channel 'group_replication_recovery' ;" \
        -e "set global group_replication_allow_local_disjoint_gtids_join=ON;START GROUP_REPLICATION;"
      done
fi

cp -n /opt/dble/extend.conf.d/* /opt/dble/conf/

# kubernetes HOSTNAME
if [ -n "$HOSTNAME" ]; then
    hostStrArray=(`echo $HOSTNAME | tr '-' ' '`)
    DBLE_NAME="${hostStrArray[0]}${hostStrArray[1]}"
    DBLE_INDEX="${hostStrArray[1]}"
    echo $DBLE_NAME
    echo $DBLE_INDEX
    sed -i "s#^-DinstanceName=.*#-DinstanceName=$DBLE_NAME#g" /opt/dble/conf/bootstrap.cnf
    sed -i "s#^-DinstanceId=.*#-DinstanceId=$DBLE_INDEX#g" /opt/dble/conf/bootstrap.cnf

fi

# replace bootstrap.cnf with env var

/bin/sh /opt/dble/bin/dble start
/bin/sh /opt/dble/bin/wait-for-it.sh 127.0.0.1:8066



echo "dble init finish"

/bin/bash