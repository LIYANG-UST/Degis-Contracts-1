import { tokens, ether, ETHER_ADDRESS, EVM_REVERT, wait } from './helpers'

const DegisToken = artifacts.require('./DegisToken');
const InsurancePool = artifacts.require('./InsurancePool');
const MOCK_USDC_ADDRESS = '0x6e95Fc19611cebD936B22Fd1A15D53d98bb31dAF';
const DEGIS_PER_BLOCK = 10;

require('chai')
    .use(require('chai-as-promised'))
    .should()

contract('InsurancePool', ([deployer, user]) => {
    let insurancepool, degistoken;

    beforeEach(async () => {
        degistoken = await DegisToken.new();
        insurancepool = await InsurancePool.new(100, degistoken.address, MOCK_USDC_ADDRESS, DEGIS_PER_BLOCK);
        await degistoken.passMinterRole(insurancepool.address, { from: deployer });
    })

    describe('testing token contract ....', () => {
        describe('success', () => {
            it('checking token name', async () => {
                expect(await degistoken.name()).to.be.eq('DegisToken')
            })
            it('checking token symbol', async () => {
                expect(await degistoken.symbol()).to.be.eq('DEGIS')
            })

            it('checking token initial total supply', async () => {
                expect(Number(await degistoken.totalSupply())).to.eq(0)
            })

            it('dBank should have Token minter role', async () => {
                expect(await degistoken.minter()).to.eq(insurancepool.address)
            })
        })
    })
    describe('failure', () => {
        it('passing minter role should be rejected', async () => {
            await degistoken.passMinterRole(user, { from: deployer }).should.be.rejectedWith(EVM_REVERT)
        })

        it('tokens minting should be rejected', async () => {
            await degistoken.mint(user, '1', { from: deployer }).should.be.rejectedWith(EVM_REVERT) //unauthorized minter
        })
    })
})

