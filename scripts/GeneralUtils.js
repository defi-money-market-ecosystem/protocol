const {BN} = require('ethereumjs-util');
const prompt = require('prompt');
prompt.start()

const throwError = (message) => {
  if (message) {
    throw new Error(message);
  } else {
    return '';
  }
}

const getGasPriceFromPrompt = async () => {
  const message = 'GasPrice (Gwei)';
  return getFromPrompt(message, 'number')
    .then(gasPriceWei => new BN(gasPriceWei).mul(new BN(1e9)).toString(10))
}

const getFromPrompt = async (message, type) => {
  let validator;
  switch (type) {
    case 'number':
      validator = /^[1-9][0-9]*$/
      break;
    case 'address':
      validator = /^(?:0x)[0-9a-f]{40}$/
      break;
    case 'hash':
      validator = /^(?:0x)[0-9a-f]{64}$/
      break;
    case 'string':
      validator = /^[a-zA-Z]+$/
      break;
    default:
      throwError(`Invalid type, found: ${type}`);
  }

  return new Promise((resolve, reject) => {
    const schema = {
      properties: {
        [message]: {
          validator,
          required: true,
          name: 'hello',
        },
      },
    };
    prompt.get(schema, (error, result) => {
      if (error) {
        reject(error);
      } else {
        resolve(result[message]);
      }
    });
  });
}

module.exports = {
  getGasPriceFromPrompt,
  getFromPrompt,
  throwError,
}