# spookyswap-xboo

Refreshed to use hardhat.

# Usage instructions

## Install Dependencies

`yarn install`

## Compile Contracts

`npx hardhat compile`

## Run Local Node

`npx hardhat node`

### or (if getting hostname errors)

`npx hardhat node --hostname 127.0.0.1`

### or (GNU screen dependency)

`./startNode.sh`

## Run Tests (automatically compiles)

### All tests
`npx hardhat test`

### Specific test
`npx hardhat test test/specificTest.js`

## Execute script

`npx hardhat run scripts/deploy.js`

## Select network

`npx hardhat test test/specificTest.js --network hardhat`

`npx hardhat run scripts/deploy.js --network opera`
