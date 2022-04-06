const HelloMarvelDC = artifacts.require('MarvelDC');

module.exports = function (deployer) {
  return deployer.then(async () => {
    

    await deployer.deploy(HelloMarvelDC, {gas: 1000000000});
  });
};
