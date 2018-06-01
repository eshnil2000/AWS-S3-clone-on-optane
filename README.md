# AWS-S3-clone-on-optane
Minio clone on Optane

## Install Docker. Make sure to install on the Storage device under consideration, not on boot drive, if evaluating storage performance. 
For memory performance, should not matter which volume / disk docker is installed on.
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
```
docker pull minio/minio
docker run -p 9001:9000 minio/minio server /data
```
# Docker will save data in container folder /data. This will be automatically deleted upon container exit
# Minio server will provide key/secret, copy for use in aws-cli

## Gui available @ http://localhost:9001
## Reference implementation http://tryoptane.intel.com:9001

## Install aws-cli
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
```
aws ‑‑endpoint‑url http://tryoptane.intel.com:9001 s3 mb s3://mybucket2 
aws --endpoint-url http://tryoptane.intel.com:9001 s3 cp _YPTuniqid_5af645ed7e1a69.83853291_SD.mp4 s3://mybucket2
```
