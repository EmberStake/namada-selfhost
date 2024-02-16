# Namada Self Host
This repository helps to quickly spin up a local version of namada blockchain and some ecosystem services and tools in a matter of seconds.    
Including : 
- A Namada blockchain with 3 validators
- Hermes for IBC transfer (by running a second namada blockchain called chain-b)
- Namada interface clone on localhost
- Namada extension with your local chain configs   

This can be helpful for curios users and developers alike.   
There are a bunch of [blog posts](https://mirror.xyz/0xe4e0B45aa2b06Df651337E3519ee6ccD81511Bf0/V8GPGi3XTf1WcL0nB2oGKo1T6X1cHfzfQCpj11tuUPI) with detailed instruction on how to install and work with this code

### Requirements
- Docker (or Docker Desktop on Windows/Mac) 
---
# Important!
IF YOU ARE UPGRADING THIS PACKAGE FROM OLDER VERSIONS MAKE SURE CORRECT NAMADA VERSIONS ARE SET IN YOUR `.env` FILE.  
you can always find the latest version supported packages in the `.env.sample` package

## Initialize settings

Make an .env from sample file, and alter values as desired
```shell
cp .env.sample .env
```
Pull images from docker hub or build them from scratch.  
To pull images do 
```shell
docker compose pull
```
Or, build images from the dockerfile (takes more time and requires a lot of resources) :

```shell
docker compose build
```

# Run The Network

To start the blockchain with 3 validators
```shell
docker compose up -d
```
for the first time launching it give it 1-2 min to download necessary files and setup the chain. then you can use it   

#### Check logs
```shell
docker compose logs -f 
```
#### Execute commands
exec into one of the validators , e.g.
```shell
docker compose exec namada-1 bash
```
then you can run any commands over the blockchain. e.g. :
```shell
namada --version
```
each container has a wallet funded with tokens, you can make tx from this wallet or fund new wallets, for example on validator 1 container
```shell
docker compose exec namada-1 bash
namadac balance --owner namada-1-wallet
```

for more information about commands, check the [official docs](https://docs.namada.net/users)

# Hermes and IBC transfers
To test hermes on a Namada <> Namada channel , we need another instance of namada blockchain. this is included under hermes profile in docker compose file.   
To run chain B and the hermes container    
```shell
docker compose --profile hermes up -d
```
this will create chain-b , another namada blockchain with single validator and sets configs on the hermes and create a channel between two blockchains.   
Hermes takes some time to be functional, so the check logs before start using it 
```shell
docker compose logs -f hermes
```
now exec into chain-b and get an address wallet from there
```shell
docker compose exec chain-b bash
namadaw list
```
in another terminal exec into namada-1 and transfer any tokens to chain-b
```shell
docker compose exec namada-1 bash
namadac ibc-transfer --amount 5 --source namada-1-wallet --receiver <ADDRESS_WALLET_ON_CHAIN_B> --token nam --channel-id channel-0
```
get back into chain-b terminal, after a short time query the balance of your wallet and you should see tokens have arrived

# Namada Interface & Extension

This stack comes with a container named `interface` which serves the [official namada-interface](https://github.com/anoma/namada-interface)
It also builds the Namada Browser extension during the startup. The chain ID is automatically set to the local running Namada blockchain.    
You can tweak supported environment variables through the `.env` file.    
Building cloud take a very long time to finish, so be patient, in the meantime you can work with the CLI.    
```shell
docker compose --profile interface up -d
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
docker compose --profile hermes --profile interface down -v -t 0
```

# Know Issues
- The UI does not show correct Account balances
- Interface Docker image size is very large and it's build time takes ages