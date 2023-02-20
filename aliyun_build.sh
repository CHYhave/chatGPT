#!/bin/bash
# mvn打包项目
mvn clean package -DskipTests

repository=docker.io
aliyun_user=chyhave
aliyun_password=chenhaoyu123

namespace=chyhave
image=chatgpt
version=latest

podman buildx build -t $repository/$namespace/$image:$version --platform linux/amd64 .
podman login $repository --username $aliyun_user --password $aliyun_password
podman push $repository/$namespace/$image:$version
