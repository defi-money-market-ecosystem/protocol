const {BN} = require('ethereumjs-util');

const linkContract = (artifact, libraryName, address) => {
  artifact.bytecode = artifact.bytecode.split(`__${libraryName}_________________________`).join(address.substring(2))
};

const deployContract = async (artifact, params, deployer, gasLimit, web3, gasPrice) => {
  web3 = !!web3 ? web3 : require("./index").web3;
  const contract = new web3.eth.Contract(artifact.abi, null, {data: '0x' + artifact.bytecode});
  const mappedParams = params.map(param => {
    if (BN.isBN(param)) {
      return '0x' + param.toString(16);
    } else {
      return param;
    }
  });
  return contract
    .deploy({
      data: artifact.bytecode,
      arguments: mappedParams.length > 0 ? mappedParams : undefined
    })
    .send({
      from: deployer,
      gas: gasLimit,
      gasPrice: gasPrice || require("./index").defaultGasPrice,
    })
    .on('receipt', receipt => {
      console.log(`Contract Deployed at address ${receipt.contractAddress} with TransactionHash: ${receipt.transactionHash}`);
    })
    .then(async contract => {
      const instance = await artifact.at(contract.options.address);
      instance.contract.address = instance.address;
      return instance.contract;
    });
};

const callContract = async (artifact, methodName, params, sender, gasLimit, value, web3, gasPrice) => {
  web3 = !!web3 ? web3 : require("./index").web3;

  console.log(`Calling ${methodName} at ${artifact.address}...`);
  const mappedParams = params.map(param => {
    if (BN.isBN(param)) {
      return param.toString(10);
    } else {
      return param;
    }
  });
  const [p1, p2, p3, p4, p5, p6, p7, p8, p9, p10] = mappedParams;

  const contract = new web3.eth.Contract(artifact.abi || artifact._jsonInterface, artifact.address);
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
    .send({
      from: sender,
      gas: gasLimit,
      gasPrice: gasPrice || require('./index').defaultGasPrice,
      value: value ? value : undefined,
    })
    .then((receipt) => {
      console.log(`Called ${methodName} at ${artifact.address} with TransactionHash ${receipt.transactionHash}`);
    })
};

module.exports = {
  callContract,
  deployContract,
  linkContract,
};