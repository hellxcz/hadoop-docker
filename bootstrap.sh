#!/bin/bash

: ${HADOOP_PREFIX:=/usr/local/hadoop}
: ${NIFI_PREFIX:=/usr/local/nifi-1.1.2}
: ${ZEPPELIN_PREFIX:=/usr/local/zeppelin-0.7.0-bin-all}
: ${SPARK_HOME:=/usr/local/spark-2.1.0-bin-hadoop2.7}

$HADOOP_PREFIX/etc/hadoop/hadoop-env.sh

rm /tmp/*.pid

# installing libraries if any - (resource urls added comma separated to the ACP system variable)
cd $HADOOP_PREFIX/share/hadoop/common ; for cp in ${ACP//,/ }; do  echo == $cp; curl -LO $cp ; done; cd -

# altering the core-site configuration
sed s/HOSTNAME/$HOSTNAME/ /usr/local/hadoop/etc/hadoop/core-site.xml.template > /usr/local/hadoop/etc/hadoop/core-site.xml


service sshd start
$HADOOP_PREFIX/sbin/start-dfs.sh
$HADOOP_PREFIX/sbin/start-yarn.sh
$HADOOP_PREFIX/sbin/mr-jobhistory-daemon.sh start historyserver

$NIFI_PREFIX/bin/nifi.sh start
$ZEPPELIN_PREFIX/bin/zeppelin-daemon.sh start


if [[ $1 == "-d" ]]; then
  while true; do sleep 1000; done
fi

if [[ $1 == "-bash" ]]; then
  /bin/bash
fi
