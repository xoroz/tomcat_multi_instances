#!/bin/bash
# Criar nova instancia no Tomcat de maneira padronizada e automatizada
# Felipe Ferreira 09/07/14
# Versao 2.0
# 01/09/14
# update 12/08/14 Felipe - Acertos check_start, logrotate
# update 12/08/14 Felipe - add SOURCE URL, novo pacote
# update 10/09/14 Felipe - Nova estrutura no /opt, nao tenta iniciar, limpeza geral
# update 20/05/16 Felipe - Public version - github 

## TO-DO
#OK - verificar se existe java na maquina, caso nao sair e avisar
#OK - acertar rotate e initd 
# verificar se pacote esta atualizado caso nao fazer o download do novo

if [ ! $3 ]; then
   echo "Usage $0 <instancia> <portaWeb> <user>"
   exit 0
fi
NOVA=$1
PORT1=$2
USER=$3
JHOME=""
START_COUNT=0
MAX_RESTART_COUNT=2
SOURCE="https://github.com/xoroz/tomcat_multi_instances/blob/master/tomcat.ORIG.tar?raw=true"
DOWNLOAD_TOMCAT="https://github.com/xoroz/tomcat_multi_instances/blob/master/apache-tomcat-6.0.41.zip?raw=true"

function checks() {
#check if java is installed and try to find JAVA_HOME
if type -p java; then
    _java=java
    version=$("$_java" -version 2>&1 | awk -F '"' '/version/ {print $2}')
    echo "JAVA found version $version"
else
    echo "no java found"
    exit 1
fi

if [ "$(whoami)" != 'root' ]; then
        echo "You have no permission to run $0 as non-root user."
        exit 1;
fi

}

function gettom() {
#verifica se esta na globo.com ou infoglobo, baixa o pacote e descompacta
 rm -f /opt/tomcat.ORIG.tar 
 cd /opt && wget --no-check-certificate -q $SOURCE -O tomcat.ORIG.tar 
 echo -e "Downloading \n $SOURCE \n"
if [ ! -f /opt/tomcat.ORIG.tar ]; then
 echo "ERROR - /opt/tomcat.ORIG.tar not found"
 exit 2
else
 echo "OK - File download"
fi

cd /opt && rm -rf tomcat.ORIG
tar -zxf tomcat.ORIG.tar && chown $USER.$USER -R tomcat.ORIG/ && \
mv -f tomcat.ORIG/create_tomcat /usr/local/bin && \
mv -f tomcat.ORIG/destroy_tomcat /usr/local/bin && \
mv -f tomcat.ORIG/list_tomcat /usr/local/bin && \
chmod +x /usr/local/bin/*_tomcat 
echo $?
if [ $? -ne 0 ];then 
 echo "ERROR - could not retrive tomcat Original!"
 exit 2
else
 echo "Tomcat downloaded at: /opt/tomcat.ORIG"
fi
}


PASS=`date +%s | sha256sum | base64 | head -c 10`
#set +x 

################################## MAIN ########################

echo "Creating new tomcat instance ${NOVA} from /opt/tomcat.ORIG"
if [ ! -d /opt/tomcat.ORIG ]; then
   echo "ERROR - Directory /opt/tomcat.ORIG already found"
   checks
   gettom
fi

U=`id -u $USER`
if [ ! -z $U ]; then
        echo "$USER already found"
else
        echo "$USER is being created"
        useradd $USER -c "For tomcat.$NOVA"
fi

cp -Rpn /opt/tomcat.ORIG /opt/tomcat.$NOVA
rm -rf /opt/tomcat.$NOVA/logs/ 
rm -rf /var/log/tomcat.$NOVA
mkdir /var/log/tomcat.$NOVA
ln -s /var/log/tomcat.$NOVA /opt/tomcat.$NOVA/logs
chown $USER. -R /var/log/tomcat.$NOVA && chown $USER. -R /opt/tomcat.$NOVA
sleep 3

echo ". Acertando logrotate"
mv -f  /opt/tomcat.$NOVA/tomcat.ORIG.rotate /etc/logrotate.d/tomcat.$NOVA
sed -i "s/ORIG/$NOVA/g" /etc/logrotate.d/tomcat.$NOVA 

echo ". Acertando tomcat6.conf instancia $NOVA porta $PORT1 $PORT2"
sed -i "s/ORIG/$NOVA/g"  /opt/tomcat.${NOVA}/conf/tomcat6.conf
sed -i "s/8080/$PORT1/g" /opt/tomcat.${NOVA}/conf/tomcat6.conf
sed -i "s/JHOME/$JHOME/g" /opt/tomcat.${NOVA}/conf/tomcat6.conf

echo ". Acertando /etc/init.d/tomcat.${NOVA}"
mv -f  /opt/tomcat.$NOVA/tomcat.ORIG.initd /etc/init.d/tomcat.$NOVA
sed -i "s/ORIG/${NOVA}/g" /etc/init.d/tomcat.$NOVA 


echo ". Acertando senha gerada automaticamente"
sed -i "s/info2014/$PASS/g" /opt/tomcat.${NOVA}/conf/tomcat-users.xml

echo ". Acertando server.xml"
echo ".. Acertando porta WEB $PORT1"
sed -i "s/8080/${PORT1}/g" /opt/tomcat.${NOVA}/conf/server.xml
PORTS=`echo "$PORT1" | cut -c 1-2`
PORTS="${PORTS}05"
echo "..  Acertando porta de shutdown de 8005 a $PORTS"
sed -i "s/8005/${PORTS}/g" /opt/tomcat.${NOVA}/conf/server.xml

#echo "OBS: A porta 8443 e usada para redirect HTTPS e Porta AJP 8009 foram desabilitadas"

echo "................................"
echo "/etc/init.d/tomcat.$NOVA start"
echo "Teste logar: "
echo "  http://${HOSTNAME}:${PORT1}/console"
echo "Usuario: tomcat Senha: $PASS"
echo " "
echo "Falta:"
echo "- Adicionar ao startup:"
echo "chkconfig --add tomcat.$NOVA"
echo "chkconfig --level 3 tomcat.$NOVA on"
echo " "
echo " Lembrar de acertar memoria de cada instancia"
echo "................................"
