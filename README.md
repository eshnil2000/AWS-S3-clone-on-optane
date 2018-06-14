## AWS-S3-clone-on-Optane
Minio clone on Optane device

## Install Docker 
https://www.docker.com/
Why Docker? Easy install, auto clean on container exit. Storage device can be exposed as filesystem with close to native performance by mapping volume if required.
Install Docker on the Storage device under consideration, not on boot drive, if evaluating storage performance. By default, container
storage is mapped to drive where docker is installed.
For memory performance, should not matter which volume / disk docker is installed on.
Reference: https://linuxconfig.org/how-to-move-docker-s-default-var-lib-docker-to-another-directory-on-ubuntu-debian-linux
```
sudo apt-get update --assume-yes
sudo apt-get install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update --assume-yes
sudo apt-get install docker-ce --assume-yes
```
## Install minio server
https://github.com/minio/minio
```
docker pull minio/minio
docker run -p 9001:9000 minio/minio server /data
```
Docker will save data in container folder /data. This will be automatically deleted upon container exit
Minio server will provide key/secret, copy for use in aws-cli

#Gui available @ http://localhost:9001

## Install aws-cli
https://aws.amazon.com/cli/
```
apt‑get install python‑pip  --assume-yes
pip install awscli
pip install ‑‑upgrade pip  
```
## Configure aws-cli
```
aws configure
```
#enter AccessKey: you_key 
#enter SecretKey: your_secret 
#leave all other fields blank

## Create buckets, populate with files via aws-cli
aws-cli & these commands can be run from any device, does not need to be on the same Minio server. The same exact commands can be run
against Amazon AWS instance, aws-cli is compatible.
```
aws ‑‑endpoint‑url http://localhost:9001 s3 mb s3://mybucket2 
aws --endpoint-url http://localhost:9001 s3 cp _YPTuniqid_5af645ed7e1a69.83853291_SD.mp4 s3://mybucket2
```

## Running benchmarks
Example benchmark. Benchmark can be run from any device.
https://github.com/intel-cloud/cosbench

Constrain memory/ storage available to Minio as required for benchmarking purposes
