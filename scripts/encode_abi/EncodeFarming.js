const approveGloballyTrustedProxy = async (dmgYieldFarming, proxyAddress, isTrusted) => {
  const actualAbi = dmgYieldFarming.contract.methods.approveGloballyTrustedProxy(
    proxyAddress,
    isTrusted,
  ).encodeABI();

  // 0000000000000000000000004cb120dd1d33c9a3de8bc15620c7cd43418d77e227c3a77
  // 00000000000000000000000000000000000000000000000000000000000000000000000
  // 00000000000000000000000000000000000000000000000e10

  console.log(`approveGloballyTrustedProxy at ${dmgYieldFarming.address} `, actualAbi);
};

module.exports = {
  approveGloballyTrustedProxy,
};