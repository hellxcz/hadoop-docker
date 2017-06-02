# Creates pseudo distributed hadoop 2.7.1
#
# docker build -t sequenceiq/hadoop .

FROM sequenceiq/pam:centos-6.5
MAINTAINER HELLER

USER root

# install dev tools
RUN yum clean all; \
    rpm --rebuilddb; \
    yum install -y curl which tar sudo openssh-server openssh-clients rsync
# update libselinux. see https://github.com/sequenceiq/hadoop-docker/issues/14

#RUN yum update -y libselinux

# passwordless ssh
RUN ssh-keygen -q -N "" -t dsa -f /etc/ssh/ssh_host_dsa_key
RUN ssh-keygen -q -N "" -t rsa -f /etc/ssh/ssh_host_rsa_key
RUN ssh-keygen -q -N "" -t rsa -f /root/.ssh/id_rsa
RUN cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys


# java
RUN curl -LO 'http://download.oracle.com/otn-pub/java/jdk/7u71-b14/jdk-7u71-linux-x64.rpm' -H 'Cookie: oraclelicense=accept-securebackup-cookie'
RUN rpm -i jdk-7u71-linux-x64.rpm
RUN rm jdk-7u71-linux-x64.rpm

RUN curl -LO 'http://download.oracle.com/otn-pub/java/jdk/8u111-b14/jdk-8u111-linux-x64.rpm' -H 'Cookie: oraclelicense=accept-securebackup-cookie'
RUN rpm -i jdk-8u111-linux-x64.rpm
RUN rm jdk-8u111-linux-x64.rpm

RUN /usr/sbin/alternatives --install /usr/bin/java java /usr/java/jdk1.7.0_71/bin/java 2
RUN /usr/sbin/alternatives --set java /usr/java/jdk1.7.0_71/bin/java
#RUN echo 2 | /usr/sbin/alternatives --config java

RUN rm -rf /usr/java/default
RUN ln -sf /usr/java/jdk1.7.0_71 /usr/java/default

ENV JAVA_HOME /usr/java/default
ENV PATH $PATH:$JAVA_HOME/bin
RUN rm /usr/bin/java && ln -s $JAVA_HOME/bin/java /usr/bin/java

# download native support
RUN mkdir -p /tmp/native
# RUN curl -L https://github.com/sequenceiq/docker-hadoop-build/releases/download/v2.7.1/hadoop-native-64-2.7.1.tgz | tar -xz -C /tmp/native

# hadoop
# RUN curl -s http://www.eu.apache.org/dist/hadoop/common/hadoop-2.7.1/hadoop-2.7.1.tar.gz | tar -xz -C /usr/local/
RUN curl -s http://www.eu.apache.org/dist/hadoop/common/hadoop-2.8.0/hadoop-2.8.0.tar.gz | tar -xz -C /usr/local/
# RUN cd /usr/local && ln -s ./hadoop-2.7.1 hadoop
RUN cd /usr/local && ln -s ./hadoop-2.8.0 hadoop

#NIFI
#http://apache.miloslavbrada.cz/nifi/1.1.2/nifi-1.1.2-bin.tar.gz
RUN curl -s http://apache.miloslavbrada.cz/nifi/1.1.2/nifi-1.1.2-bin.tar.gz | tar -xz -C /usr/local/

#zeppelin
#http://apache.miloslavbrada.cz/zeppelin/zeppelin-0.7.0/zeppelin-0.7.0-bin-all.tgz
RUN curl -s http://apache.miloslavbrada.cz/zeppelin/zeppelin-0.7.0/zeppelin-0.7.0-bin-all.tgz | tar -xz -C /usr/local/
# https://zeppelin.apache.org/docs/0.7.0/install/configuration.html
# cp zeppelin-env.sh.template zeppelin-env.sh
# zeppelin-env.sh , ZEPPELIN_PORT, 8081 -- maybe

#spark
RUN curl -s http://d3kbcqa49mib13.cloudfront.net/spark-2.1.0-bin-hadoop2.7.tgz | tar -xz -C /usr/local/

ENV HADOOP_PREFIX /usr/local/hadoop
ENV HADOOP_COMMON_HOME /usr/local/hadoop
ENV HADOOP_HDFS_HOME /usr/local/hadoop
ENV HADOOP_MAPRED_HOME /usr/local/hadoop
ENV HADOOP_YARN_HOME /usr/local/hadoop
ENV HADOOP_CONF_DIR /usr/local/hadoop/etc/hadoop
ENV YARN_CONF_DIR $HADOOP_PREFIX/etc/hadoop
ENV NIFI_PREFIX /usr/local/nifi-1.1.2
ENV ZEPPELIN_PREFIX /usr/local/zeppelin-0.7.0-bin-all
ENV SPARK_PREFIX /usr/local/spark-2.1.0-bin-hadoop2.7
ENV SPARK_HOME /usr/local/spark-2.1.0-bin-hadoop2.7

RUN sed -i '/^export JAVA_HOME/ s:.*:export JAVA_HOME=/usr/java/default\nexport HADOOP_PREFIX=/usr/local/hadoop\nexport HADOOP_HOME=/usr/local/hadoop\n:' $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh
RUN sed -i '/^export HADOOP_CONF_DIR/ s:.*:export HADOOP_CONF_DIR=/usr/local/hadoop/etc/hadoop/:' $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh
#RUN . $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh

RUN mkdir $HADOOP_PREFIX/input
RUN cp $HADOOP_PREFIX/etc/hadoop/*.xml $HADOOP_PREFIX/input

# pseudo distributed
ADD core-site.xml.template $HADOOP_PREFIX/etc/hadoop/core-site.xml.template
RUN sed s/HOSTNAME/localhost/ /usr/local/hadoop/etc/hadoop/core-site.xml.template > /usr/local/hadoop/etc/hadoop/core-site.xml
ADD hdfs-site.xml $HADOOP_PREFIX/etc/hadoop/hdfs-site.xml

ADD mapred-site.xml $HADOOP_PREFIX/etc/hadoop/mapred-site.xml
ADD yarn-site.xml $HADOOP_PREFIX/etc/hadoop/yarn-site.xml

RUN $HADOOP_PREFIX/bin/hdfs namenode -format

# fixing the libhadoop.so like a boss
# RUN rm -rf /usr/local/hadoop/lib/native
# RUN mv /tmp/native /usr/local/hadoop/lib

ADD ssh_config /root/.ssh/config
RUN chmod 600 /root/.ssh/config
RUN chown root:root /root/.ssh/config

# # installing supervisord
# RUN yum install -y python-setuptools
# RUN easy_install pip
# RUN curl https://bitbucket.org/pypa/setuptools/raw/bootstrap/ez_setup.py -o - | python
# RUN pip install supervisor
#
# ADD supervisord.conf /etc/supervisord.conf

ADD bootstrap.sh /etc/bootstrap.sh
RUN chown root:root /etc/bootstrap.sh
RUN chmod 700 /etc/bootstrap.sh

ENV BOOTSTRAP /etc/bootstrap.sh

# workingaround docker.io build error
RUN ls -la /usr/local/hadoop/etc/hadoop/*-env.sh
RUN chmod +x /usr/local/hadoop/etc/hadoop/*-env.sh
RUN ls -la /usr/local/hadoop/etc/hadoop/*-env.sh

# fix the 254 error code
RUN sed  -i "/^[^#]*UsePAM/ s/.*/#&/"  /etc/ssh/sshd_config
RUN echo "UsePAM no" >> /etc/ssh/sshd_config
RUN echo "Port 2122" >> /etc/ssh/sshd_config

#NIFI configuration
ADD nifi/nifi-env.sh $NIFI_PREFIX/bin

#ZEPPELIN configuration
ADD zeppelin/zeppelin-env.sh $ZEPPELIN_PREFIX/conf

#spark configuration
# RUN echo "export SPARK_HOME=$SPARK_PREFIX" >> /etc/bash.bashrc \
# && echo 'export PATH=$PATH:$SPARK_PREFIX/bin'>> /etc/bash.bashrc
ADD spark/spark-env.sh $SPARK_PREFIX/conf

RUN service sshd start && $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh && $HADOOP_PREFIX/sbin/start-dfs.sh && $HADOOP_PREFIX/bin/hdfs dfs -mkdir -p /user/root
RUN service sshd start && $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh && $HADOOP_PREFIX/sbin/start-dfs.sh && $HADOOP_PREFIX/bin/hdfs dfs -put $HADOOP_PREFIX/etc/hadoop/ input

CMD ["/etc/bootstrap.sh", "-d"]

# create data volumes
RUN mkdir -p /hdfs/volume1

VOLUME /hdfs/volume1

RUN bash -c "mkdir -p $NIFI_PREFIX/{database_repository,flowfile_repository,content_repository,provenance_repository}"
RUN bash -c "mkdir -p $ZEPPELIN_PREFIX/logs"


VOLUME ["$NIFI_PREFIX/database_repository", \
        "$NIFI_PREFIX/flowfile_repository", \
        "$NIFI_PREFIX/content_repository", \
        "$NIFI_PREFIX/provenance_repository", \
        "$ZEPPELIN_PREFIX/notebook", \
        "$ZEPPELIN_PREFIX/logs"]

# Hdfs ports
EXPOSE 50010 50020 50070 50075 50090 8020 9000
# Mapred ports
EXPOSE 10020 19888
#Yarn ports
EXPOSE 8030 8031 8032 8033 8040 8042 8088

#zeppelin ports
EXPOSE 8081
#nifi ports
EXPOSE 8080

#Other ports
EXPOSE 49707 2122
