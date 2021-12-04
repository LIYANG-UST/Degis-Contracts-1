import { AssertionError } from "chai";
import { tokens, ether, ETHER_ADDRESS, EVM_REVERT, wait } from "./helpers";

const DegisToken = artifacts.require("DegisToken");
const Mock_USD = artifacts.require("MockUSD");
const InsurancePool = artifacts.require("InsurancePool");
const EmergencyPool = artifacts.require("EmergencyPool");
const LPToken = artifacts.require("LPToken");

const DEGIS_PER_BLOCK = web3.utils.toBN(10 ** 18);

const lottery_rinkeby = "0xa85D352ED54952E2C4e147B43A7D461bb395CbeE";

require("chai").use(require("chai-as-promised")).should();

contract("InsurancePool", ([deployer, user, other]) => {
  let lptoken, usdc, emergency, insurancepool, degistoken;

  beforeEach(async () => {
    lptoken = await LPToken.new();
    degistoken = await DegisToken.new();
    usdc = await Mock_USD.new();
    emergency = await EmergencyPool.new(usdc.address);
    insurancepool = await InsurancePool.new(
      degistoken.address,
      emergency.address,
      usdc.address,
      lottery_rinkeby
    );
  });

  describe("testing token contract ....", () => {
    describe("success", () => {
      it("checking token name", async () => {
        expect(await degistoken.name()).to.be.eq("DegisToken");
      });
      it("checking token symbol", async () => {
        expect(await degistoken.symbol()).to.be.eq("DEGIS");
      });

      it("checking token initial total supply", async () => {
        expect(Number(await degistoken.totalSupply())).to.eq(0);
      });

      it("insurance pool should have Token minter role", async () => {
        expect(await degistoken.minter()).to.eq(insurancepool.address);
      });
    });

    describe("failure", () => {
      it("passing minter role should be rejected", async () => {
        await degistoken
          .passMinterRole(user, { from: other })
          .should.be.rejectedWith(EVM_REVERT);
      });

      it("tokens minting should be rejected", async () => {
        await degistoken
          .mint(user, "1", { from: deployer })
          .should.be.rejectedWith(EVM_REVERT); //unauthorized minter
      });
    });
  });
});
