#!/bin/bash

KubernetesDashboardUsername=${1}
KubernetesDashboardPassword=${2}

echo "#################"
echo "START INIT-DASHBOARD."

su ubuntu -c "nohup kubectl proxy > /dev/null 2>&1 &"

echo "*/5  *  *  *  *    ubuntu    nohup kubectl proxy > /dev/null 2>&1 &" | tee --append /etc/crontab

apt-get -y install apache2 fail2ban

a2enmod proxy
a2enmod proxy_http
a2enmod headers
a2enmod rewrite

service apache2 restart

echo "${KubernetesDashboardPassword}" | htpasswd -i -c /opt/htpasswd-dashboard ${KubernetesDashboardUsername}

cat <<'EOF' > /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
ServerAdmin webmaster@localhost
DocumentRoot /var/www
ProxyRequests Off
ProxyPreserveHost Off

AllowEncodedSlashes NoDecode

<Proxy *>
AuthType Basic
AuthName "Kubernetes Dashboard"
AuthBasicProvider file
AuthUserFile "/opt/htpasswd-dashboard"
Require valid-user
</Proxy>

RequestHeader unset Authorization

Redirect "/ui"  /api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/#!/overview?namespace=_all
ProxyPass        /ui     !

ProxyPass        /       http://127.0.0.1:8001/ nocanon
ProxyPassReverse /       http://127.0.0.1:8001/
CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

service apache2 restart

TOKEN=`su ubuntu -c 'kubectl get secret $(kubectl get serviceaccount kubernetes-dashboard -n kube-system -o jsonpath="{.secrets[0].name}") -n kube-system -o jsonpath="{.data.token}"' | base64 --decode`

echo ${TOKEN} > /opt/kubernetes-dashboard-auth-token

echo "########################"
echo "DONE INIT-DASHBOARD. EXIT 0"
echo "########################"
exit 0
