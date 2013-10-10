#!/bin/bash

# Set these parameters
mysqlRoot=RootPassword

# === Do not modify anything in this section ===

# Regenerate the SSH host key
/bin/rm /etc/ssh/ssh_host_*
dpkg-reconfigure openssh-server

# Copy over config files
cp /srv/gitlab_ci/config/puma.rb /home/gitlab_ci/gitlab-ci/config/puma.rb
cp /srv/gitlab_ci/config/application.yml /home/gitlab_ci/gitlab-ci/config/application.yml

password=$(cat /srv/gitlab_ci/config/database.yml | grep -m 1 password | sed -e 's/  password: "//g' | sed -e 's/"//g')
echo "Password from database config extracted as $password"
cp /srv/gitlab_ci/config/database.yml /home/gitlab_ci/gitlab-ci/config/database.yml
chown gitlab_ci:gitlab_ci -R /home/gitlab_ci/gitlab-ci/config/ && chmod o-rwx -R /home/gitlab_ci/gitlab-ci/config/

# Link data directories to /srv/gitlab_ci/data
#rm -R /home/gitlab_ci/tmp && ln -s /srv/gitlab_ci/data/tmp /home/gitlab_ci/tmp && chown -R git /srv/gitlab_ci/data/tmp/ && chmod -R u+rwX  /srv/gitlab_ci/data/tmp/
#rm -R /home/git/.ssh && ln -s /srv/gitlab_ci/data/ssh /home/git/.ssh && chown -R git:git /srv/gitlab_ci/data/ssh && chmod -R 0700 /srv/gitlab_ci/data/ssh && chmod 0700 /home/git/.ssh
#chown -R git:git /srv/gitlab_ci/data/gitlab-satellites
#chown -R git:git /srv/gitlab_ci/data/repositories && chmod -R ug+rwX,o-rwx /srv/gitlab_ci/data/repositories && chmod -R ug-s /srv/gitlab_ci/data/repositories/
#find /srv/gitlab_ci/data/repositories/ -type d -print0 | xargs -0 chmod g+s

# Change repo path in gitlab-shell config
#sed -i -e 's#/home/git/repositories#/srv/gitlab_ci/data/repositories#g' /home/gitlab_ci-shell/config.yml

# Link MySQL dir to /srv/gitlab_ci/data
#mv /var/lib/mysql /var/lib/mysql-tmp
#ln -s /srv/gitlab_ci/data/mysql /var/lib/mysql

# ==============================================

# === Delete this section if resoring data from previous build ===

rm -R /srv/gitlab_ci/data/mysql
mv /var/lib/mysql-tmp /srv/gitlab_ci/data/mysql

# Start MySQL
mysqld_safe &
sleep 5

# Initialize MySQL
mysqladmin -u root --password=temprootpass password $mysqlRoot
echo "CREATE USER 'gitlab_ci'@'localhost' IDENTIFIED BY '$password';" | \
  mysql --user=root --password=$mysqlRoot
echo "CREATE DATABASE IF NOT EXISTS gitlab_ci_production DEFAULT CHARACTER SET \
    'utf8' COLLATE 'utf8_unicode_ci';" | mysql --user=root --password=$mysqlRoot
echo "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON \
    gitlab_ci_production.* TO 'gitlab_ci'@'localhost';" | mysql \
    --user=root --password=$mysqlRoot

cd /home/gitlab_ci/gitlab-ci
su gitlab_ci -c "bundle exec rake db:setup force=yes RAILS_ENV=production"
sleep 5
su gitlab_ci -c "bundle exec whenever -w force=yes RAILS_ENV=production"

# ================================================================

# Manually create /var/run/sshd
mkdir /var/run/sshd

# Set the dns server
echo "192.168.1.1" > /etc/resolv.conf

# change the root password
echo "root:password" | chpasswd

# Delete firstrun script
rm /srv/gitlab_ci/firstrun.sh
