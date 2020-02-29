const {callContract, deployContract} = require('./ContractUtils');
const {BN} = require('ethereumjs-util');

global.delayedOwner = null;

const tenMinutesInSeconds = new BN('600');
const oneHourInSeconds = new BN('3600');
const sixHoursInSeconds = new BN('21600');
const oneMinuteInSeconds = new BN('60');

const defaultUint = 0;
const defaultAddress = '0x0000000000000000000000000000000000000000';

const deployTimeDelay = async (loader, environment, deployer) => {
  const DelayedOwner = loader.truffle.fromArtifact('DelayedOwner');

  console.log("Deploying delayed owner...");
  delayedOwner = await deployContract(
    DelayedOwner,
    [dmmController.address, tenMinutesInSeconds],
    deployer,
    5e6,
  );

  let delay;
  if (environment === 'PRODUCTION') {
    delay = oneHourInSeconds;
  } else {
    delay = oneMinuteInSeconds;
  }

  console.log(`Using time delay of ${delay.div(new BN('60')).toString()} minutes`);

  console.log('Adding time delay for DmmController#enableMarket...');
  await callContract(
    delayedOwner,
    'addDelay',
    [
      dmmController.address,
      dmmController.methods.enableMarket(defaultUint).encodeABI().slice(0, 10),
      delay,
    ],
    deployer,
    3e5,
  );

  console.log('Adding time delay for DmmController#disableMarket...');
  await callContract(
    delayedOwner,
    'addDelay',
    [
      dmmController.address,
      dmmController.methods.disableMarket(defaultUint).encodeABI().slice(0, 10),
      delay,
    ],
    deployer,
    3e5,
  );

  console.log('Adding time delay for DmmController#setInterestRateInterface...');
  await callContract(
    delayedOwner,
    'addDelay',
    [
      dmmController.address,
      dmmController.methods.setInterestRateInterface(defaultAddress).encodeABI().slice(0, 10),
      delay,
    ],
    deployer,
    3e5,
  );

  console.log('Adding time delay for DmmController#setOffChainAssetValuator...');
  await callContract(
    delayedOwner,
    'addDelay',
    [
      dmmController.address,
      dmmController.methods.setOffChainAssetValuator(defaultAddress).encodeABI().slice(0, 10),
      delay,
    ],
    deployer,
    3e5,
  );

  console.log('Adding time delay for DmmController#setOffChainCurrencyValuator...');
  await callContract(
    delayedOwner,
    'addDelay',
    [
      dmmController.address,
      dmmController.methods.setOffChainCurrencyValuator(defaultAddress).encodeABI().slice(0, 10),
      delay,
    ],
    deployer,
    3e5,
  );

  console.log('Adding time delay for DmmController#setUnderlyingTokenValuator...');
  await callContract(
    delayedOwner,
    'addDelay',
    [
      dmmController.address,
      dmmController.methods.setUnderlyingTokenValuator(defaultAddress).encodeABI().slice(0, 10),
      delay,
    ],
    deployer,
    3e5,
  );

  console.log('Adding time delay for DmmController#setMinCollateralization...');
  await callContract(
    delayedOwner,
    'addDelay',
    [
      dmmController.address,
      dmmController.methods.setMinCollateralization(defaultUint).encodeABI().slice(0, 10),
      delay,
    ],
    deployer,
    3e5,
  );

  console.log('Adding time delay for DmmController#setMinReserveRatio...');
  await callContract(
    delayedOwner,
    'addDelay',
    [
      dmmController.address,
      dmmController.methods.setMinReserveRatio(defaultUint).encodeABI().slice(0, 10),
      delay,
    ],
    deployer,
    3e5,
  );

  console.log('Adding time delay for DmmController#increaseTotalSupply...');
  await callContract(
    delayedOwner,
    'addDelay',
    [
      dmmController.address,
      dmmController.methods.increaseTotalSupply(defaultUint, defaultUint).encodeABI().slice(0, 10),
      delay,
    ],
    deployer,
    3e5,
  );

  console.log('Adding time delay for DmmController#decreaseTotalSupply...');
  await callContract(
    delayedOwner,
    'addDelay',
    [
      dmmController.address,
      dmmController.methods.decreaseTotalSupply(defaultUint, defaultUint).encodeABI().slice(0, 10),
      delay,
    ],
    deployer,
    3e5,
  );

  console.log('Adding time delay for DmmController#adminWithdrawFunds...');
  await callContract(
    delayedOwner,
    'addDelay',
    [
      dmmController.address,
      dmmController.methods.adminWithdrawFunds(defaultUint, defaultUint).encodeABI().slice(0, 10),
      delay,
    ],
    deployer,
    3e5,
  );

  console.log('Adding time delay for DmmController#adminDepositFunds...');
  await callContract(
    delayedOwner,
    'addDelay',
    [
      dmmController.address,
      dmmController.methods.adminDepositFunds(defaultUint, defaultUint).encodeABI().slice(0, 10),
      delay,
    ],
    deployer,
    3e5,
  );
};

module.exports = {
  deployTimeDelay,
};