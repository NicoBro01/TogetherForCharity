This is a Dapp created to incentivize the donations and improve traditional charity systems. You can create your own donation campaign or join other campaigns.

In order to deploy the Dapp, make sure you have a package manager and hardhat installed and follow this steps:

1. Compile contracts: `yarn hardhat compile` or `npm hardhat compile`;

2. Choose a network where deploy it;

3. Create a .env folder to insert: API Key of the deployer wallet, a blockchain explorer API Key, an RPC URL to connect to a blockchain node;

4. Deploy: `yarn hardhat deploy --network` or `npm hardhat deploy --network` followed by the chosen network name

(In 'hardhat.config.js' and 'helper-hardhat-config.js' there are already Sepolia, Mumbai and Polygon network configurations; feel free to configure the network you want).

In order to make the Dapp working, you have to run 'utils/Keeper.js' script to verify new campaigns on the blockchain explorer and to make them end. Before running it, follow this steps:

1. Insert in the .env file the deployed Contract Factory address (you can find it in logs after the deploy);

2. Create an ABI folder where you have to put json files of ABIs of the contract factory and campaigns (Note that ABIs can be found in 'artifacts/contracts' folder created by Solidity compiler after the compilation).

Now you can run Keepers.js: `yarn hardhat run utils/Keeper.js --network` or `npm hardhat run utils/Keeper.js --network` followed by the chosen network name.
