const encodeDmmTokenConstructor = async (web3, symbol, name, decimals, minMint, minRedeem, totalSupply) => {
  const params = web3.eth.abi.encodeParameters(
    ['string', 'string', 'uint8', 'uint', 'uint', 'uint'],
    [symbol, name, decimals, minMint, minRedeem, totalSupply.toString()],
  );

  console.log(`DmmToken Constructor for ${symbol}: `, params)
};

const encodeDmmEtherConstructor = async (web3, wethAddress, symbol, name, decimals, minMint, minRedeem, totalSupply) => {
  const params = web3.eth.abi.encodeParameters(
    ['address', 'string', 'string', 'uint8', 'uint', 'uint', 'uint'],
    [wethAddress, symbol, name, decimals, minMint, minRedeem, totalSupply.toString()],
  );

  console.log(`DmmEther Constructor `, params)
};

const addMarket = async (dmmController, delayedOwner, underlyingAddress, symbol, name, decimals, minMint, minRedeem, totalSupply) => {
  const innerAbi = dmmController.contract.methods.addMarket(
    underlyingAddress,
    symbol,
    name,
    decimals,
    minMint,
    minRedeem,
    totalSupply.toString(),
  ).encodeABI();

  const actualAbi = delayedOwner.contract.methods.transact(
    dmmController.address,
    innerAbi,
  ).encodeABI();

  console.log(`Add market for ${symbol}: `, actualAbi)
};

const adminDepositFunds = async (delayedOwner, controller, dmmTokenId, amount) => {
  const innerAbi = controller.contract.methods.adminDepositFunds(dmmTokenId.toString(), amount.toString()).encodeABI();

  // const actualAbi = delayedOwner.contract.methods.transact(
  //   controller.address,
  //   innerAbi,
  // ).encodeABI();

  // console.log(`adminDepositFunds for ${dmmTokenId.toString()}: `, actualAbi);
  console.log(`adminDepositFunds for ${dmmTokenId.toString()}: `, innerAbi);
};

const adminWithdrawFunds = async (delayedOwner, controller, dmmTokenId, amount) => {
  const innerAbi = controller.contract.methods.adminWithdrawFunds(dmmTokenId.toString(), amount.toString()).encodeABI();

  console.log(`adminWithdrawFunds for ${dmmTokenId.toString()}: `, innerAbi);
};

const decreaseTotalSupply = async (delayedOwner, controller, dmmTokenId, amount) => {
  const innerAbi = controller.contract.methods.decreaseTotalSupply(dmmTokenId.toString(), amount.toString()).encodeABI();

  // const actualAbi = delayedOwner.contract.methods.transact(controller.address, innerAbi,).encodeABI();

  // console.log(`decreaseTotalSupply for ${dmmTokenId.toString()}: `, actualAbi);
  console.log(`decreaseTotalSupply for ${dmmTokenId.toString()}: `, innerAbi);
};

const setUnderlyingTokenValuator = async (delayedOwner, dmmController, underlyingTokenValuatorAddress) => {
  const innerAbi = dmmController.contract.methods.setUnderlyingTokenValuator(underlyingTokenValuatorAddress).encodeABI();

  console.log(`setUnderlyingTokenValuator: `, dmmController.address, ' ', innerAbi);
};

const setOffChainAssetValuator = async (delayedOwner, dmmController, offChainAssetValuatorAddress) => {
  const innerAbi = dmmController.contract.methods.setOffChainAssetValuator(offChainAssetValuatorAddress).encodeABI();
  const actualAbi = delayedOwner.contract.methods.transact(dmmController.address, innerAbi).encodeABI();

  console.log(`setOffChainAssetValuator: `, actualAbi);
};

const pauseEcosystem = async (delayedOwner, controller) => {
  const innerAbi = controller.contract.methods.pause().encodeABI();
  const actualAbi = delayedOwner.contract.methods.transact(controller.address, innerAbi).encodeABI();

  console.log(`pauseEcosystem: `, actualAbi);
};

module.exports = {
  encodeDmmTokenConstructor,
  encodeDmmEtherConstructor,
  addMarket,
  adminDepositFunds,
  adminWithdrawFunds,
  decreaseTotalSupply,
  setUnderlyingTokenValuator,
  setOffChainAssetValuator,
  pauseEcosystem,
}