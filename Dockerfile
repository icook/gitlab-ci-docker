FROM ubuntu:12.04
ENV MYSQLTMPROOT temprootpass

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
RUN apt-get install -y wget curl gcc checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev libreadline6-dev libc6-dev libssl-dev libmysql++-dev make build-essential zlib1g-dev openssh-server git-core libyaml-dev postfix libpq-dev libicu-dev redis-server

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
sudo adduser --disabled-login --gecos 'GitLab CI' gitlab_ci

# Install MySQL
RUN echo mysql-server mysql-server/root_password password $MYSQLTMPROOT | debconf-set-selections;\
  echo mysql-server mysql-server/root_password_again password $MYSQLTMPROOT | debconf-set-selections;\
  apt-get install -y mysql-server mysql-client libmysqlclient-dev

#######
# Install GitLab
RUN cd /home/git;\
  su git -c "git clone https://github.com/gitlabhq/gitlabhq.git gitlab";\
  cd /home/git/gitlab;\
  su git -c "git checkout 6-1-stable"

# Misc configuration stuff
RUN cd /home/git/gitlab;\
  chown -R git tmp/;\
  chown -R git log/;\
  chmod -R u+rwX log/;\
  chmod -R u+rwX tmp/;\
  su git -c "mkdir /home/git/gitlab-satellites";\
  su git -c "mkdir tmp/pids/";\
  su git -c "mkdir tmp/sockets/";\
  chmod -R u+rwX tmp/pids/;\
  chmod -R u+rwX tmp/sockets/;\
  su git -c "mkdir public/uploads";\
  chmod -R u+rwX public/uploads;\
  su git -c "cp config/unicorn.rb.example config/unicorn.rb";\
  su git -c "git config --global user.name 'GitLab'";\
  su git -c "git config --global user.email 'gitlab@localhost'";\
  su git -c "git config --global core.autocrlf input"

RUN cd /home/git/gitlab;\
  gem install charlock_holmes --version '0.6.9.4';\
  su git -c "bundle install --deployment --without development test postgres aws"

# Install init scripts
RUN cd /home/git/gitlab;\
  cp lib/support/init.d/gitlab /etc/init.d/gitlab;\
  chmod +x /etc/init.d/gitlab;\
  update-rc.d gitlab defaults 21

EXPOSE 80
EXPOSE 22

ADD . /srv/gitlab

RUN chmod +x /srv/gitlab/start.sh;\
  chmod +x /srv/gitlab/firstrun.sh

CMD ["/srv/gitlab/start.sh"]
