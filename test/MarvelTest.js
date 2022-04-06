
const MarvelDC = artifacts.require('MarvelDC')
const web3 = require('web3')



// all numbers are converted to BigInt so they can be passed to Solidity

class Computation {
  constructor (description, numToSelect, numToReward, rewardAmount, targetFunctionID, publicKeyN) {
    this._id=web3.utils.soliditySha3({ t: 'string', v: description})
    this._description=description
    this._numToSelect=numToSelect
    this._numToReward=numToReward
    this._rewardAmount=rewardAmount
    this._targetFunctionID=targetFunctionID
    this._publicKeyN=publicKeyN
  }
}

function fastModularExponentiation(a, b, n) {

  a = a % n;
  let result = 1;
  let x = a;

  while(b > 0){
    let leastSignificantBit = b % 2;
    b = Math.floor(b / 2);

    if (leastSignificantBit == 1) {
      result = result * x;
      result = result % n;
    }

    x = x * x;
    x = x % n;
  }
  return result;
}


function targetFunction1(results) {
  return results.reduce((a,b) =>a+b,0)/results.length;
}


contract('MarvelDC', async function (accounts) {
  let inst
  let numComputers=8
  let numToSelect=BigInt(4)
  let numToReward=BigInt(2)
  let rewardAmount=1
  const computerDeposit = 1
  it('should be deployed', async function () {
    inst = await MarvelDC.deployed()
  })
  
  it('register computers', async function () {
    for (let step = 0; step < 8; step++) {
      await inst.Computer_Register({ from: accounts[step], value: computerDeposit })
    }
    
  })
  let description="keccak256 "
  let result=web3.utils.soliditySha3({ t: 'uint', v: '0'})
  
  let targetFunctionID =BigInt(1)
  let privateKey=2011
  let publicKeyE=3
  let publicKeyN = 3127
  let computation = new Computation(description, numToSelect, numToReward, rewardAmount, targetFunctionID, publicKeyN)
  //console.log('computation:', computation)
  
  let selectedComputers=[];
  let blockchainResponses=[];

  
  it('request computation', async function () {
    await inst.Request_Computation(computation._id, 
	computation._description, 
	computation._numToSelect, 
	computation._numToReward, 
	computation._rewardAmount, 
	computation._targetFunctionID, 
	computation._publicKeyN , { from: accounts[numComputers], gasLimit: 10000000, value: 2*(computation._rewardAmount*Number(computation._numToReward))})
	
    for (let step = 0; step < Number(numToSelect); step++) {
      selectedComputers[step]=await inst.getSelectedComputerByPosition.call(computation._id, step);
    }
    //console.log("selected comps",selectedComputers)
  })
  
  it('submit results', async function () {
    // not correctly handling big number, not important for demonstration
    for (let step = 0; step < Number(numToSelect); step++) {
      //perform encryption on result using RSA exponentiation
      let response= fastModularExponentiation(((Number(result)%publicKeyN)+(step)),3,publicKeyN)
      let done= await inst.Submit_Result(computation._id, response, { from: selectedComputers[step]})
    }
    
    
  })
  
  it('distribute rewards', async function () {
    
    decryptedResponses=[]
    
    for (let step = 0; step < Number(numToSelect); step++) {
      let encResponse= Number(await inst.getComputerResponsesByAddress.call(computation._id, selectedComputers[step]))
      	
      decryptedResponses[step]=fastModularExponentiation(encResponse, privateKey, publicKeyN)
     
    }
    //this function must match the one used on chain. In this case, the average.
    let target =targetFunction1(decryptedResponses)
    let distances=[]
    for (let step = 0; step < Number(numToSelect); step++) {
      distances.push((target-decryptedResponses[step])**2);
    }
    

    //check pre-computation rep
    //for (let i = 0; i < numComputers; i++) {
      //console.log("Pre-computation Rep:", accounts[i], Number(await inst.getReputation(accounts[i])))
    //} 
    
    distances.sort()
    orderedAddress=[]
    orderedResults=[]
    for (let i = 0; i< Number(numToSelect); i++) {
    	let j=0
    	while (orderedAddress.length==i){
    	    if ( (target-decryptedResponses[j])**2 == distances[i]){
    	    	//create ordered array of results and corresponding computer
    	    	orderedAddress.push(selectedComputers[j])
    	    	orderedResults.push(decryptedResponses[j])
    	    	//remove from array in case of matches
    	    	decryptedResponses.splice(j,1);
    	    	selectedComputers.splice(j,1);
    	    }
    	    j++
    	}
    }
    
    //for (let i = 0; i < Number(numToReward); i++) {
      //console.log("should be rewarded:", orderedAddress[i])
    //} 
    
    await inst.Reveal_Results(computation._id, orderedAddress, orderedResults, { from: accounts[numComputers]} )
    
    //check post-computation rep lines up with computation
    //for (let i = 0; i < numComputers; i++) {
      //console.log("Post-computation Rep:", accounts[i], Number(await inst.getReputation(accounts[i])))
    //} 
    
    
  })
  
  

 

})


