#!/bin/bash

# Install Maven (if not already installed)
apt-get update
apt-get install -y ca-certificates curl wget
apt-get install -y openjdk-8-jdk
apt-get install -y maven

mkdir -p /home/yuhaneu/.m2/repository/org/seleniumhq
mkdir -p /home/yuhaneu/Desktop
chown -R yuhaneu:yuhaneu /home/yuhaneu/.m2
chown -R yuhaneu:yuhaneu /home/yuhaneu/Desktop

su - yuhaneu -c 'cp -r /home/yuhaneu/workspace/selenium-custom-library/selenium /home/yuhaneu/.m2/repository/org/seleniumhq'

# compile apps
for app in $(ls /home/yuhaneu/workspace/fse2019)
do
    su - yuhaneu -c "cd /home/yuhaneu/workspace/fse2019/$app && mvn clean compile"
done

# install evosuite
su - yuhaneu -c 'cd /home/yuhaneu/workspace/evosuite && mvn clean install -DskipTests'

cd /home/yuhaneu

# Install Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -aG docker yuhaneu

docker pull selenium/standalone-chrome:3.141.59-dubnium
