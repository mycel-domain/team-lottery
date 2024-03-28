import { ethers } from "hardhat";
import {
  ethers as ethersV6,
  BigNumberish,
  BytesLike,
  AddressLike,
} from "ethers";
import { expect } from "chai";

import {
  VaultV2,
  TwabController,
  ERC20Mintable,
  YieldVaultMintRate,
} from "../../typechain-types";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { HardhatEthersProvider } from "@nomicfoundation/hardhat-ethers/internal/hardhat-ethers-provider";

describe("Contract Test", () => {
  let owner: HardhatEthersSigner;
  let claimer: HardhatEthersSigner;
  let yieldFeeRecipient: HardhatEthersSigner;
  let addr1: HardhatEthersSigner;
  let addr2: HardhatEthersSigner;
  let addr3: HardhatEthersSigner;
  let addr4: HardhatEthersSigner;
  let provider: HardhatEthersProvider;
  let tokenContract: ERC20Mintable;
  let twabController: TwabController;
  let yieldVaultMintRate: YieldVaultMintRate;
  let vault: VaultV2;

  async function deployToken(_owner: HardhatEthersSigner) {
    const TokenFactory = await ethers.getContractFactory("ERC20Mintable");
    const token = await TokenFactory.deploy("USDC", "USDC", 6, _owner.address);
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

  async function deployYieldVaultMintRate(
    _owner: HardhatEthersSigner,
    token: any
  ) {
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
    _owner: HardhatEthersSigner,
    _claimer: HardhatEthersSigner,
    _yieldFeeRecipient: HardhatEthersSigner,
    token: ERC20Mintable,
    twabController: TwabController,
    yieldVaultMintRate: YieldVaultMintRate
  ): Promise<VaultV2> {
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

    tokenContract = await deployToken(owner);
    twabController = await deployTwabController();
    yieldVaultMintRate = await deployYieldVaultMintRate(
      owner,
      tokenContract.target
    );
    await tokenContract
      .connect(owner)
      .grantRole(await tokenContract.MINTER_ROLE(), yieldVaultMintRate.target);
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
      const token = await deployToken(owner);
      const tokenAddress = token.target;
      expect(tokenAddress).to.not.be.undefined;
    });

    it("Should deploy the TwabController contract", async () => {
      const twabController = await deployTwabController();
      const twabControllerAddress = twabController.target;
      expect(twabControllerAddress).to.not.be.undefined;
    });

    it("Should deploy the YieldVaultMintRate contract", async () => {
      const token = await deployToken(owner);
      const yieldVaultMintRate = await deployYieldVaultMintRate(
        owner,
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
  describe("Draw functions", () => {
    it("Should deposit tokens", async () => {
      const balance = ethers.parseUnits("1000", 6);
      await mintAndDeposit(balance, addr1);
      expect(
        await twabController.balanceOf(vault.target, addr1.address)
      ).to.equal(balance);
      expect(await vault.totalAssets()).to.equal(balance);
      expect(await tokenContract.balanceOf(addr1.address)).to.equal(0);
    });

    it("Should withdraw tokens", async () => {
      const balance = ethers.parseUnits("1000", 6);
      await mintAndDeposit(balance, addr1);
      await vault
        .connect(addr1)
        .withdraw(balance, addr1.address, addr1.address);
      expect(
        await twabController.balanceOf(vault.target, addr1.address)
      ).to.equal(0);
    });
    it("should finalize the draw", async () => {
      const balance = ethers.parseUnits("1000", 6);
      await mintAndDeposit(balance, addr1);
      await mintAndDeposit(balance, addr2);
      await mintAndDeposit(balance, addr3);
      await mintAndDeposit(balance, addr4);

      const blockNumBefore = await ethers.provider.getBlockNumber();
      const blockBefore = await ethers.provider.getBlock(blockNumBefore);
      const timestamp =
        Number(await vault.getCurrentDrawEndTime()) -
        Number(blockBefore?.timestamp);
      await provider.send("evm_increaseTime", [timestamp]);
      await provider.send("evm_mine");

      await yieldToVault();
      const teams = await createTeam();
      const encodedTeams: BytesLike = await encodeTeams(teams);
      console.log("teams", teams);
      console.log("encodedTeams", encodedTeams);

      const drawId = await vault.currentDrawId();
      const winningNumber: bigint = BigInt(
        "70333568669866340472331338725676123169611570254888405765691075355522696984357"
      );

      await vault
        .connect(claimer)
        .finalizeDraw(drawId, winningNumber, encodedTeams);
      expect(await vault.drawIsFinalized(drawId)).to.be.true;
      await ethers.provider.send("evm_increaseTime", [-timestamp]);
      await ethers.provider.send("evm_mine");
    });
  });

  async function mintAndDeposit(amount: bigint, caller: any) {
    await tokenContract.connect(owner).mint(caller.address, amount);
    await tokenContract.connect(caller).approve(vault.target, amount);
    await vault.connect(caller).deposit(amount, caller.address);
  }
  async function yieldToVault() {
    await yieldVaultMintRate.connect(owner).yield(ethers.parseUnits("1000", 6));
  }

  type Team = {
    teamId: number;
    teamTwab: BigNumberish;
    teamPoints: BigNumberish;
    teamMembers: AddressLike[];
  };

  async function createTeam(): Promise<Team[]> {
    let teams: Team[] = [];

    const drawId = await vault.currentDrawId();
    const draw = await vault.getDraw(drawId);

    teams.push({
      teamId: 1,
      teamTwab: 200n,
      teamPoints: 100 as BigNumberish,
      teamMembers: [
        addr1.address as `0x${string}`,
        addr2.address as `0x${string}`,
      ],
    });
    teams.push({
      teamId: 2,
      teamTwab: 200n,
      teamPoints: 200 as BigNumberish,
      teamMembers: [
        addr3.address as `0x${string}`,
        addr4.address as `0x${string}`,
      ],
    });

    teams[0].teamTwab = await vault.calculateTeamTwabBetween(
      teams[0].teamMembers,
      draw.drawId
    );
    teams[1].teamTwab = await vault.calculateTeamTwabBetween(
      teams[1].teamMembers,
      draw.drawId
    );

    return teams;
  }
  async function encodeTeams(teams: Team[]): Promise<BytesLike> {
    const abiCoder = new ethersV6.AbiCoder();
    // uint8 teamId, uint256 teamTwab, uint256 teamPoints, address[] teamMembers
    const encoded = abiCoder.encode(
      [
        "tuple(uint8 teamId, uint256 teamTwab, uint256 teamPoints, address[] teamMembers)[]",
      ],
      [
        teams.map((team) => [
          team.teamId,
          team.teamTwab,
          team.teamPoints,
          team.teamMembers,
        ]),
      ]
    );
    console.log("encoded", encoded);

    const decoded = abiCoder.decode(
      [
        "tuple(uint8 teamId, uint256 teamTwab, uint256 teamPoints, address[] teamMembers)[]",
      ],
      encoded
    );
    console.log("decoded", decoded);

    return encoded as BytesLike;
  }
});
