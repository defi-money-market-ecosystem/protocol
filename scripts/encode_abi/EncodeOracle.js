const withdrawAllLink = async (loader, delayedOwner, linkAddress, recipient, amount) => {
  const OffChainAssetValuatorImplV1 = loader.truffle.fromArtifact('OffChainAssetValuatorImplV1');
  const offChainAssetValuatorImplV1 = await OffChainAssetValuatorImplV1.at("0xAcE9112EfE78D9E5018fd12164D30366cA629Ab4");
  const oracleAddress = "0x7AFe1118Ea78C1eae84ca8feE5C65Bc76CcF879e";
  const innerAbi = offChainAssetValuatorImplV1.contract.methods.withdraw(linkAddress, recipient, amount).encodeABI();

  const actualAbi = delayedOwner.contract.methods.transact(
    offChainAssetValuatorImplV1.address,
    innerAbi,
  ).encodeABI();

  console.log("withdrawAllLink: ", actualAbi);
};

const getOffChainAssetsValue = async (delayedOwner) => {
  const OffChainAssetValuatorImplV1 = loader.truffle.fromArtifact('OffChainAssetValuatorImplV1');
  const offChainAssetValuatorImplV1 = await OffChainAssetValuatorImplV1.at("0x681Ba299ee5619DC96f5d87aE0F5B19EAB3Cbe8A");
  const oracleAddress = "0x7AFe1118Ea78C1eae84ca8feE5C65Bc76CcF879e";
  const innerAbi = offChainAssetValuatorImplV1.contract.methods.submitGetOffChainAssetsValueRequest(oracleAddress).encodeABI();

  const actualAbi = delayedOwner.contract.methods.transact(
    offChainAssetValuatorImplV1.address,
    innerAbi,
  ).encodeABI();

  console.log("getOffChainAssetsValue: ", actualAbi);
};

const setOraclePayment = async (delayedOwner, offChainAssetValuator, amount) => {
  const innerAbi = offChainAssetValuator.contract.methods.setOraclePayment(amount.toString()).encodeABI();
  const actualAbi = delayedOwner.contract.methods.transact(offChainAssetValuator.address, innerAbi).encodeABI();

  console.log(`setOraclePayment: `, actualAbi);
};

const setCollateralValueJobId = async (delayedOwner, offChainAssetValuator, jobId) => {
  const innerAbi = offChainAssetValuator.contract.methods.setCollateralValueJobId(jobId).encodeABI();

  console.log(`setCollateralValueJobId: `, innerAbi);
};

const submitGetOffChainAssetsValueRequest = async (delayedOwner, offChainAssetValuator, oracleAddress) => {
  const innerAbi = offChainAssetValuator.contract.methods.submitGetOffChainAssetsValueRequest(oracleAddress).encodeABI();

  console.log(`submitGetOffChainAssetsValueRequest: `, offChainAssetValuator.address, innerAbi);
};

module.exports = {
  getOffChainAssetsValue,
  setOraclePayment,
  setCollateralValueJobId,
  submitGetOffChainAssetsValueRequest,
  withdrawAllLink,
}