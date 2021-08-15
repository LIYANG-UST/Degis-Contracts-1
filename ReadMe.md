# Degis-contracts

Codes of degis contracts and a toy model for online test.

## Preparation
### Install Truffle
```bash
npm install -g truffle
```
### Keys
- Go to Infura to get your Infura Key
- Use Metamask or other wallets to generate your private key(mnemonic)
- Store Infura Key and Private Key in the .env file


## Install Dependencies
```bash
npm install
```

## Compile and Migrate
```bash
truffle compile --all
truffle migrate --network <networkname> --reset
```

## Test
### Test with ganache (network: development)
```bash
truffle test
```

### Test with scripts
```bash
npx truffle exec scripts/<script name> --network <network name>
```
or
```bash
truffle exec scripts/<script name> --network <network name>
```

### Lite-server Test
```bash
npm run dev
```

## Structure
- contracts/: smart contracts files
- src/: frontend test files (with UI & metamask)
- scripts/: test scripts (without UI, metamask)
- test/: test files (with ganache, local test)
- truffle-config.js: config file for truffle (network, mnemonic, infuraKey)
- migrations/: migration files 
- not-finished/: not finished contracts