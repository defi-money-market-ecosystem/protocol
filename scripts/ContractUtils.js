const {BN} = require('ethereumjs-util');
const {throwError} = require('./GeneralUtils');

const getAndSetUpDeployer = (web3, deployer) => {
  if (deployer || process.env.DEPLOYER) {
    const privateKey = deployer || process.env.DEPLOYER;
    const account = web3.eth.accounts.privateKeyToAccount('0x' + privateKey);
    web3.eth.accounts.wallet.add(account);
    web3.eth.defaultAccount = account.address;
    return account.address;
  } else {
    throwError("Invalid deployer, found undefined");
  }
}

const linkContract = (artifact, libraryName, address) => {
  const dashCount = 38 - libraryName.length;
  const dashes = '_'.repeat(dashCount);
  artifact.bytecode = artifact.bytecode.split(`__${libraryName}${dashes}`).join(address.substring(2))
};

const deployContract = async (artifact, params, deployer, gasLimit, web3, gasPrice) => {
  web3 = !!web3 ? web3 : require("./initial_deployment").web3;
  const bytecode = artifact.bytecode.includes('0x') ? artifact.bytecode : `0x${artifact.bytecode}`;
  const contract = new web3.eth.Contract(artifact.abi, null, {data: bytecode});
  const mappedParams = _unrollParams(params);

  return contract
    .deploy({
      data: bytecode,
      arguments: mappedParams.length > 0 ? mappedParams : null
    })
    .send({
      from: deployer,
      gas: gasLimit,
      gasPrice: gasPrice || require("./initial_deployment").defaultGasPrice,
    })
    .on('receipt', receipt => {
      console.log(`Contract Deployed at address ${receipt.contractAddress} with TransactionHash: ${receipt.transactionHash}`);
    })
    .then(async contract => {
      return new Promise((resolve, fail) => {
        setTimeout(async () => {
          try {
            const instance = await artifact.at(contract.options.address);
            instance.contract.address = instance.address;
            resolve(instance.contract);
          } catch (error) {
            fail(error);
          }
        }, 2000);
      })
    });
};

const _unrollParams = (params) => {
  return params.map(param => {
    if (Array.isArray(param)) {
      return _unrollParams(param);
    } else if (BN.isBN(param)) {
      return param.toString(10);
    } else {
      return param;
    }
  });
};

const callContract = async (artifact, methodName, params, sender, gasLimit, value, web3, gasPrice) => {
  web3 = !!web3 ? web3 : require("./initial_deployment").web3;

  console.log(`Calling ${methodName} at ${artifact.address}...`);
  const mappedParams = _unrollParams(params);

  return _callContract(web3, artifact, methodName, mappedParams)
    .send({
      from: sender,
      gas: gasLimit,
      gasPrice: gasPrice || require('./initial_deployment').defaultGasPrice,
      value: value ? value : undefined,
    })
    .then((receipt) => {
      console.log(`Called ${methodName} at ${artifact.address} with TransactionHash ${receipt.transactionHash}`);
    })
};

const readContract = async (artifact, methodName, params, sender, web3) => {
  web3 = !!web3 ? web3 : require("./initial_deployment").web3;

  const mappedParams = _unrollParams(params);
  return _callContract(web3, artifact, methodName, mappedParams).call({from: sender});
};

const _callContract = (web3, artifact, methodName, mappedParams) => {
  const contract = new web3.eth.Contract(artifact.abi || artifact._jsonInterface, artifact.address);
  const [p1, p2, p3, p4, p5, p6, p7, p8, p9, p10] = mappedParams;
  return (!p1 ? contract.methods[methodName]()
    : !p2 ? contract.methods[methodName](p1)
      : !p3 ? contract.methods[methodName](p1, p2)
        : !p4 ? contract.methods[methodName](p1, p2, p3)
          : !p5 ? contract.methods[methodName](p1, p2, p3, p4)
            : !p6 ? contract.methods[methodName](p1, p2, p3, p4, p5)
              : !p7 ? contract.methods[methodName](p1, p2, p3, p4, p5, p6)
                : !p8 ? contract.methods[methodName](p1, p2, p3, p4, p5, p6, p7)
                  : !p9 ? contract.methods[methodName](p1, p2, p3, p4, p5, p6, p7, p8)
                    : !p10 ? contract.methods[methodName](p1, p2, p3, p4, p5, p6, p7, p8, p9)
                      : contract.methods[methodName](p1, p2, p3, p4, p5, p6, p7, p8, p9, p10))
}

module.exports = {
  callContract,
  readContract,
  deployContract,
  getAndSetUpDeployer,
  linkContract,
};