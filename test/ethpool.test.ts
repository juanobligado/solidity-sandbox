import { ethers } from 'hardhat'
import { expect } from 'chai'
import { solidity } from "ethereum-waffle";
import '@nomiclabs/hardhat-ethers'

import { ETHPool__factory, ETHPool } from '../build/types'
import { BigNumber,utils } from 'ethers'

const { getContractFactory, getSigners } = ethers

describe('ETHPool', () => {
  let poolContract: ETHPool

  beforeEach(async () => {
    // 1
    const signers = await getSigners()

    // 2
    const counterFactory = (await getContractFactory('ETHPool', signers[0])) as ETHPool__factory
    poolContract = await counterFactory.deploy()
    await poolContract.deployed()
  })

  // 4
  describe('deposit', async () => {
    it('should deposit', async () => {
      const amount = utils.parseEther('0.5');
      await poolContract.deposit({value : amount});
      const totalDeposits = await poolContract.totalDeposits();
      expect(totalDeposits.toBigInt()).to.eq(amount.toBigInt()); 
    })
  })

  describe('rewards', async () => {
    it('should fail if no deposit', async () => {
      const amount = utils.parseEther('0.5');
      await expect(poolContract.distributeReward({value : amount})).to.be.revertedWith('');
    });

    it('should get rewards after depositing', async () => {
      const amount = utils.parseEther('0.5');
      await poolContract.deposit({value : amount});
      const reward = utils.parseEther('0.25'); 
      await poolContract.distributeReward({value : reward});
      poolContract.on('WithdrawReward',(address,deposited,reward,totalW)=>{
        console.log('Withdraw Event',address,deposited,reward,totalW)
        expect(totalW).to.eq(reward + deposited);
        expect(reward).to.be.greaterThan(BigNumber.from(0));
        expect(deposited).to.be.greaterThan(BigNumber.from(0));
      });
      const myDepositWithReward = await poolContract.withdraw();

      const totalDeposits = await poolContract.totalDeposits();
      expect(totalDeposits.toNumber()).to.eq(0); 
    });
  
  });



})


