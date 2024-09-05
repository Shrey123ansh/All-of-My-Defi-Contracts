#!/bin/bash
screen -S hardhat-node -X quit
screen -d -m -S hardhat-node npx hardhat node --hostname 127.0.0.1
