# Namada Self Host
This repository helps to quickly spin up a local version of namada blockchain with 3 validators using Docker.   
This can be helpful for curios users and developers alike.   
There are a bunch of [blog posts](https://mirror.xyz/0xe4e0B45aa2b06Df651337E3519ee6ccD81511Bf0/V8GPGi3XTf1WcL0nB2oGKo1T6X1cHfzfQCpj11tuUPI) with detailed instruction on how to install and work with this code

### Requirements
- Docker (or Docker Desktop on Windows/Mac) 
---
# Important!
IF YOU ARE UPGRADING THIS PACKAGE FROM OLDER VERSIONS MAKE SURE CORRECT NAMADA VERSIONS ARE SET IN YOUR `.env` FILE.   

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
docker compose up -d namada-1 namada-2 namada-3
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

# Namada Interface & Extension

This stack comes with a container named `interface` which serves the [official namada-interface](https://github.com/anoma/namada-interface)
It also builds the Namada Browser extension during the startup. The chain ID is automatically set to the local running Namada blockchain.    
You can tweak supported environment variables through the `.env` file.    
Building cloud take a very long time to finish, so be patient, in the meantime you can work with the CLI.    
```shell
docker compose up -d interface
```
## Using the Interface
When the container is ready you can access the Interface in your browser, the default address is http://localhost:3000/

## Using The Extension
The extension files are accessible in `extensions` directory. to install the chrome wallet extension do the following :    

In Chrome, select Manage Extensions    
Click the toggle to enable Developer Mode    
Click Load Unpacked and point to the `extensions/chrome` in this project    

**Important** The extension should be reinstalled if you rebuild your CHAIN_ID changes    

# Tear Down
To remove everything
```shell
docker compose down -v
```

# Know Issues
- The UI does not show correct Account balances
- Interface Docker image size is very large and it's build time takes ages