// const {dai, link, usdc, weth} = require('./DeployTokens');
const {BN} = require('ethereumjs-util');

global.delayedOwner = null;

const tenMinutesInSeconds = new BN('600');
const sixHoursInSeconds = new BN('21600');
const oneMinuteInSeconds = new BN('60');

const defaultUint = 0;
const defaultAddress = '0x0000000000000000000000000000000000000000';

const deployTimeDelay = async (loader, environment) => {
  const DelayedOwner = loader.truffle.fromArtifact('DelayedOwner');

  delayedOwner = await DelayedOwner.new(dmmController.address, tenMinutesInSeconds, {gas: 5e6});

  let delay;
  if (environment === 'PRODUCTION') {
    delay = sixHoursInSeconds;
  } else {
    delay = oneMinuteInSeconds;
  }

  console.log(`Using time delay of ${delay.div(new BN('60')).toString()} minutes`);

  console.log('Adding time delay for DmmController#enableMarket...');
  await delayedOwner.addDelay(
    dmmController.address,
    dmmController.contract.methods.enableMarket(defaultUint).encodeABI().slice(0, 10),
    delay
  );

  console.log('Adding time delay for DmmController#disableMarket...');
  await delayedOwner.addDelay(
    dmmController.address,
    dmmController.contract.methods.disableMarket(defaultUint).encodeABI().slice(0, 10),
    delay
  );

  console.log('Adding time delay for DmmController#setInterestRateInterface...');
  await delayedOwner.addDelay(
    dmmController.address,
    dmmController.contract.methods.setInterestRateInterface(defaultAddress).encodeABI().slice(0, 10),
    delay
  );

  console.log('Adding time delay for DmmController#setCollateralValuator...');
  await delayedOwner.addDelay(
    dmmController.address,
    dmmController.contract.methods.setCollateralValuator(defaultAddress).encodeABI().slice(0, 10),
    delay
  );

  console.log('Adding time delay for DmmController#setUnderlyingTokenValuator...');
  await delayedOwner.addDelay(
    dmmController.address,
    dmmController.contract.methods.setUnderlyingTokenValuator(defaultAddress).encodeABI().slice(0, 10),
    delay
  );

  console.log('Adding time delay for DmmController#setMinCollateralization...');
  await delayedOwner.addDelay(
    dmmController.address,
    dmmController.contract.methods.setMinCollateralization(defaultUint).encodeABI().slice(0, 10),
    delay
  );

  console.log('Adding time delay for DmmController#setMinReserveRatio...');
  await delayedOwner.addDelay(
    dmmController.address,
    dmmController.contract.methods.setMinReserveRatio(defaultUint).encodeABI().slice(0, 10),
    delay
  );

  console.log('Adding time delay for DmmController#increaseTotalSupply...');
  await delayedOwner.addDelay(
    dmmController.address,
    dmmController.contract.methods.increaseTotalSupply(defaultUint, defaultUint).encodeABI().slice(0, 10),
    delay
  );

  console.log('Adding time delay for DmmController#decreaseTotalSupply...');
  await delayedOwner.addDelay(
    dmmController.address,
    dmmController.contract.methods.decreaseTotalSupply(defaultUint, defaultUint).encodeABI().slice(0, 10),
    delay
  );

  console.log('Adding time delay for DmmController#adminWithdrawFunds...');
  await delayedOwner.addDelay(
    dmmController.address,
    dmmController.contract.methods.adminWithdrawFunds(defaultUint, defaultUint).encodeABI().slice(0, 10),
    delay
  );

  console.log('Adding time delay for DmmController#adminDepositFunds...');
  await delayedOwner.addDelay(
    dmmController.address,
    dmmController.contract.methods.adminDepositFunds(defaultUint, defaultUint).encodeABI().slice(0, 10),
    delay
  );
};

module.exports = {
  deployTimeDelay,
};