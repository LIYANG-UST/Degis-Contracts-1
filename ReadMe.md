# Degis-contracts

Codes of degis contracts and a toy model for online test.

## Dependencies
```
npm install -g truffle
```

## Preparation
```
npm install
```

## Compile and Migrate
```
truffle compile --all
truffle migrate --network <networkname> --reset
```

## Lite-server Test
```
npm run dev
```

## Structure
- contracts/: smart contracts files
- src/: frontend test files
- test/: test files (have not begun)
- truffle-config.js: config file for truffle (network, mnemonic, infuraKey)
- migrations/: migration files 
- not-finished/: not finished contracts