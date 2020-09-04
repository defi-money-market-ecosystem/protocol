const setBalance = async (token, recipient, amount) => {
  const actualAbi = token.contract.methods.setBalance(recipient, amount.toString()).encodeABI();
  console.log("setBalance: ", actualAbi);
};

const transferOwnership = async (ownerContract, newOwnerAddress) => {
  const actualABI = ownerContract.contract.methods.transferOwnership(newOwnerAddress).encodeABI();
  console.log(`transferOwnership of ${ownerContract.address} `, actualABI)
}

const claimOwnershipForDelayedOwner = async (delayedOwner) => {
  const innerAbi = delayedOwner.contract.methods.claimOwnership().encodeABI();

  console.log("claimOwnership: ", innerAbi);
};

const sendTokensToRecipient = async (token, recipient, amount) => {
  const actualAbi = token.contract.methods.transfer(recipient, amount.toString()).encodeABI();

  console.log(`transfer to ${recipient} ${token.address}: `, actualAbi);
};

const sendTokensFromDelayedOwnerToRecipient = async (token, delayedOwner, recipient, amount) => {
  const actualAbi = token.contract.methods.transfer(recipient, amount.toString()).encodeABI();

  console.log(`transfer token=[${token.address}] from delayed owner to ${recipient}: `, actualAbi);
};

const withdrawFromAtm = async (delayedOwner, atmContract, tokenAddress, recipient, amount) => {
  const innerAbi = atmContract.contract.methods.withdraw(tokenAddress, recipient, amount.toString()).encodeABI();
  const actualAbi = delayedOwner.contract.methods.transact(atmContract.address, innerAbi).encodeABI();

  console.log(`withdrawFromAtm for ${tokenAddress.toString()}: `, actualAbi);
};

module.exports = {
  setBalance,
  transferOwnership,
  claimOwnershipForDelayedOwner,
  sendTokensToRecipient,
  sendTokensFromDelayedOwnerToRecipient,
  withdrawFromAtm,
};