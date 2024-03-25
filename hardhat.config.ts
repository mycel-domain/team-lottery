import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 1000,
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
