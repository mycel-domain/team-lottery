import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-viem";
import "@nomicfoundation/hardhat-ethers";
const gasLimit = 60000000;

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 200,
        // details: {
        //   yulDetails: {
        //     optimizerSteps: "u",
        //   },
        // },
      },
    },
  },
};

export default config;
