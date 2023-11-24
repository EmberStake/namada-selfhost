# Namada Self Host
This repository helps to quickly spin up a local version of namada blockchain with 3 validators using Docker.   
This can be helpful for curios users and developers alike.   
There are a bunch of [blog posts](https://mirror.xyz/0xe4e0B45aa2b06Df651337E3519ee6ccD81511Bf0/V8GPGi3XTf1WcL0nB2oGKo1T6X1cHfzfQCpj11tuUPI) with detailed instruction on how to install and work with this code

### Requirements
- Docker (or Docker Desktop on Windows/Mac) 
---

## Initialize settings

Make an .env from sample file, and alter values as desired
```shell
cp .env.sample .env
```
Pull image from docker hub or build it from scratch.  
To pull images do 
```shell
docker compose pull
```
Or, build images from the dockerfile (takes more time and requires a lot of RAM) :

```shell
docker compose build
```

# Run The Network

To start the blockchain 
```shell
docker compose up -d
```
for the first time launching it give it 2-3 min to download necessary files and setup the chain. then you can use it   

#### Check logs
```shell
docker compose logs -f 
```
#### Execute commands
exec into one the validators , e.g.
```shell
docker compose exec namada-1 bash
```

then you can run any commands over the blockchain. e.g. :
```shell
namada --version
```

for more information about commands, check the [official docs](https://docs.namada.net/users)

# Tear Down
To remove everything
```shell
docker compose down -v
```