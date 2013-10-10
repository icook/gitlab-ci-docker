#!/bin/bash

# start SSH
/usr/sbin/sshd

# start redis
redis-server > /dev/null 2>&1 &
sleep 5

# Run the firstrun script
/bin/bash -x /srv/gitlab_ci/firstrun.sh || true

# remove PIDs created by GitLab init script
rm /home/gitlab_ci/tmp/pids/*

# start mysql
mysqld_safe &

# start gitlab
service gitlab_ci start

echo "Gitlab CI now running on container port 9292"

tail -f /home/gitlab_ci/gitlab-ci/log/production.log
