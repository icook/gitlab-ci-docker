FROM ubuntu:12.04

# Run upgrades
RUN echo deb http://us.archive.ubuntu.com/ubuntu/ precise universe multiverse >> /etc/apt/sources.list;\
  echo deb http://us.archive.ubuntu.com/ubuntu/ precise-updates main restricted universe >> /etc/apt/sources.list;\
  echo deb http://security.ubuntu.com/ubuntu precise-security main restricted universe >> /etc/apt/sources.list;\
  echo udev hold | dpkg --set-selections;\
  echo initscripts hold | dpkg --set-selections;\
  echo upstart hold | dpkg --set-selections;\
  apt-get update;\
  apt-get -y upgrade

# Install dependencies
RUN apt-get install -y wget curl gcc checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev libreadline6-dev libc6-dev libssl-dev libmysql++-dev make build-essential zlib1g-dev openssh-server git-core libyaml-dev postfix libpq-dev libicu-dev redis-server git

# Install Git
RUN add-apt-repository -y ppa:git-core/ppa;\
  apt-get update;\
  apt-get -y install git

# Install Ruby
RUN mkdir /tmp/ruby;\
  cd /tmp/ruby;\
  curl --progress http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-1.9.3-p392.tar.gz | tar xz;\
  cd ruby-1.9.3-p392;\
  chmod +x configure;\
  ./configure;\
  make;\
  make install;\
  gem install bundler --no-ri --no-rdoc

# Create Git user
RUN adduser --disabled-login --gecos 'GitLab CI' gitlab_ci

# Install MySQL
RUN echo mysql-server mysql-server/root_password password $MYSQLTMPROOT | debconf-set-selections;\
  echo mysql-server mysql-server/root_password_again password $MYSQLTMPROOT | debconf-set-selections;\
  apt-get install -y mysql-server mysql-client libmysqlclient-dev

# Misc configuration stuff
RUN cd /home/gitlab_ci;\
  chown -R gitlab_ci tmp/;\
  chown -R gitlab_ci log/;\
  chmod -R u+rwX log/;\
  chmod -R u+rwX tmp/;\
  su gitlab_ci -c "mkdir tmp/pids/";\
  su gitlab_ci -c "mkdir tmp/sockets/";\
  chmod -R u+rwX tmp/pids/;\
  chmod -R u+rwX tmp/sockets/;\
  su gitlab_ci -c "git config --global user.name 'GitLab CI'";\
  su gitlab_ci -c "git config --global user.email 'gitlab_ci@localhost'";\
  su gitlab_ci -c "git config --global core.autocrlf input"

# Install GitLab CI
RUN cd /home/gitlab_ci;\
  su gitlab_ci -c "git clone https://github.com/gitlabhq/gitlab-ci.git";\
  cd gitlab-ci;\
  su gitlab_ci -c "git checkout 3-2-stable";\
  su gitlab_ci -c "bundle install --without development test postgres --deployment"

# Install init scripts
RUN cd /home/gitlab_ci/gitlab-ci;\
  cp lib/support/init.d/gitlab_ci /etc/init.d/gitlab_ci;\
  chmod +x /etc/init.d/gitlab_ci;\
  update-rc.d gitlab_ci defaults 21

EXPOSE 9292

ADD . /srv/gitlab_ci

RUN chmod +x /srv/gitlab_ci/start.sh;\
  chmod +x /srv/gitlab_ci/firstrun.sh

CMD ["/srv/gitlab_ci/start.sh"]
