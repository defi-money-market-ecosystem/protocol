const changeFunctionDelay = async (delayedOwner, contractAddress, fnCall, fnName) => {
  const actualAbi = delayedOwner.contract.methods.addDelay(
    contractAddress,
    fnCall.encodeABI().slice(0, 10),
    functionDelay.toString(),
  ).encodeABI();

  // 0000000000000000000000004cb120dd1d33c9a3de8bc15620c7cd43418d77e227c3a77
  // 00000000000000000000000000000000000000000000000000000000000000000000000
  // 00000000000000000000000000000000000000000000000e10

  console.log(`Function selector for ${fnName}: `, fnCall.encodeABI().slice(0, 10));

  console.log(`changeFunctionDelay with ID ${fnName.toString()}: `, actualAbi);
};

const executeDelayedTransaction = async (delayedOwner, transactionId) => {
  const actualAbi = delayedOwner.contract.methods.executeTransaction(
    transactionId.toString()
  ).encodeABI();

  // console.log(`delayedTransaction with ID ${transactionId.toString()}: `, actualAbi);
  console.log(`delayedTransaction with ID ${transactionId.toString()}: `, web3.eth.abi.encodeParameters(['uint'], [transactionId]));
};

const setTimeToLive = async (delayedOwner, secondsBN) => {
  const actualAbi = delayedOwner.contract.methods.setTimeToLive(
    secondsBN.toString()
  ).encodeABI();

  console.log(`setTimeToLive: `, actualAbi);
};

module.exports = {
  changeFunctionDelay,
  executeDelayedTransaction,
  setTimeToLive,
};