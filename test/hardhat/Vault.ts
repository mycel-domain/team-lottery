import { ethers } from "hardhat";
import { expect } from "chai";

describe("Contract Test", () => {
  let owner: any;
  let claimer: any;
  let yieldFeeRecipient: any;
  let addr1: any;
  let addr2: any;
  let addr3: any;
  let addr4: any;
  let provider: any;
  let tokenContract: any;
  let twabController: any;
  let yieldVaultMintRate: any;
  let vault: any;

  async function deployToken(_owner: any) {
    const TokenFactory = await ethers.getContractFactory("ERC20Mintable");
    const token = await TokenFactory.deploy("USDC", "USDC", 6, _owner);
    return token;
  }

  async function deployTwabController() {
    const blockNumBefore = await ethers.provider.getBlockNumber();
    const blockBefore = await ethers.provider.getBlock(blockNumBefore);
    const TwabFactory = await ethers.getContractFactory("TwabController");
    const twabController = await TwabFactory.deploy(
      3600,
      blockBefore?.timestamp as number
    );
    return twabController;
  }

  async function deployYieldVaultMintRate(_owner: any, token: any) {
    const YieldVaultMintRateFactory = await ethers.getContractFactory(
      "YieldVaultMintRate"
    );
    const yieldVaultMintRate = await YieldVaultMintRateFactory.deploy(
      token,
      "Spore USDC Yield Vault",
      "syvUSDC",
      _owner
    );
    return yieldVaultMintRate;
  }

  async function deployContract(
    _owner: any,
    _claimer: string,
    _yieldFeeRecipient: string,
    token: any,
    twabController: any,
    yieldVaultMintRate: any
  ) {
    const DrawLibFactory = await ethers.getContractFactory("DrawCalculation");
    const DrawLib = await DrawLibFactory.deploy();

    const VaultFactory = await ethers.getContractFactory("VaultV2", {
      libraries: {
        DrawCalculation: DrawLib,
      },
    });

    const vault = await VaultFactory.deploy(
      token.target!,
      "Spore USDC Vault",
      "spvUSDC",
      twabController.target!,
      yieldVaultMintRate.target!,
      claimer.address!,
      yieldFeeRecipient.address!,
      0,
      _owner.address!
    );
    return vault;
  }

  beforeEach(async () => {
    [owner, claimer, yieldFeeRecipient, addr1, addr2, addr3, addr4] =
      await ethers.getSigners();

    provider = ethers.provider;

    tokenContract = await deployToken(owner.address);
    twabController = await deployTwabController();
    yieldVaultMintRate = await deployYieldVaultMintRate(
      owner.address,
      tokenContract.target
    );
    vault = await deployContract(
      owner,
      claimer,
      yieldFeeRecipient,
      tokenContract,
      twabController,
      yieldVaultMintRate
    );
  });
  describe("Deploy functions", () => {
    it("Should deploy the Token contract", async () => {
      const token = await deployToken(owner.address);
      const tokenAddress = token.target;
      expect(tokenAddress).to.not.be.undefined;
    });

    it("Should deploy the TwabController contract", async () => {
      const twabController = await deployTwabController();
      const twabControllerAddress = twabController.target;
      expect(twabControllerAddress).to.not.be.undefined;
    });

    it("Should deploy the YieldVaultMintRate contract", async () => {
      const token = await deployToken(owner.address);
      const yieldVaultMintRate = await deployYieldVaultMintRate(
        owner.address,
        token.target
      );
      const yieldVaultMintRateAddress = yieldVaultMintRate.target;
      expect(yieldVaultMintRateAddress).to.not.be.undefined;
    });

    it("Should deploy the Vault contract", async () => {
      const contract = await deployContract(
        owner,
        claimer,
        yieldFeeRecipient,
        tokenContract,
        twabController,
        yieldVaultMintRate
      );
      const contractAddress = contract.target;
      expect(contractAddress).to.not.be.undefined;
      expect(await contract.owner()).to.equal(owner.address);
      expect(await contract.claimer()).to.equal(claimer.address);
      expect(await contract.yieldFeeRecipient()).to.equal(
        yieldFeeRecipient.address
      );
      expect(await contract.twabController()).to.equal(twabController.target);
      expect(await contract.yieldVault()).to.equal(yieldVaultMintRate.target);
      expect(await contract.asset()).to.equal(tokenContract.target);
    });
  });
});
