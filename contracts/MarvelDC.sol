// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;


import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract MarvelDC{

	// this might throw and error. Check before deploying
    function hash(bytes memory input) internal pure returns (bytes32) {
        return bytes32(keccak256(input));
    }
    
    bytes32 public _randomness;
    
    function refreshRandomness()
        public
        returns (bytes32 random)
    {
        _randomness = hash(abi.encodePacked(_randomness));
        return (_randomness);
    }
    
    mapping(bytes32 => Computation_Marvel) _computations;
    mapping(address => uint256) _reputations;
    address[] computers;
    uint256 _escrowComputer;
    uint256 initialReputation=10;
    uint256 _relayerFee;
    uint256 _finaliseBounty;
    uint256 constant _phaseLength = 100;
    // repMultiplier needed to provide block producers with an increase in reputation
    uint256 constant _repMultiplier=10000;
    
    constructor() {
    	//do we need to set randomness?
    
        // set appropriate relayer fee, maybe updatable?
        _relayerFee = 1;

        // set computer escrow
        _escrowComputer = 1;
        _finaliseBounty = 1;
    }

     struct Computation_Marvel {
    	address _requester;
        uint _numToSelect;
        uint _numToReward;
        uint256 _rewardAmount;
        uint _targetFunctionID;
        uint256 _publicKeyN;
        uint _startingBlock;
        bool _active;
        address[] _selectedComputers;
        mapping(address => uint256) _responses;
    }

	//in a public blockchain this randomness needs to be sourced correctly, here we just repeatedly hash a common seed
    
    
    

	// DONE
    function Computer_Register() public payable returns (bool) {
        require(
            msg.value >= _escrowComputer,
            "Computer register must deposit escrow "
        );
        require((_reputations[msg.sender]==0), "Registration ID already taken");

        _reputations[msg.sender] = initialReputation*_repMultiplier;
        computers.push(msg.sender);

        
        return true;
    }
    
    event ComputationSubmitted(string description);
    

    
    // we assume an RSA encryption. To allow for on-chain verification, the exponent is hard-coded to 3
    function Request_Computation(bytes32 _id, string memory description,
        uint _numToSelect,
        uint _numToReward,
        uint256 _rewardAmount,
        uint _targetFunctionID,
        uint256 _publicKeyN) public payable returns (bool) {
        // _numToReward*_rewardAmount is required for rewarding, while a further _numToReward*_rewardAmount is required for escrow.
        require(
            _numToSelect <= computers.length,
            "Too many computers selected"
        );
    	require(
            msg.value >= 2*(uint256(_numToReward)*_rewardAmount),
            "Requester has not depositted enough"
        );
        
        require(
        //we want to check hash(description)=_id
            _id == keccak256(abi.encodePacked(description)),
            "id does not match description"
        );
        emit ComputationSubmitted(description);
    	
    	Computation_Marvel storage new_comp= _computations[_id];
    	
    	new_comp._requester=msg.sender;
    	new_comp._numToSelect=_numToSelect;
    	new_comp._numToReward=_numToReward;
    	new_comp._rewardAmount=_rewardAmount;
    	new_comp._targetFunctionID=_targetFunctionID;
        new_comp._publicKeyN=_publicKeyN;
        new_comp._startingBlock=block.number;
        new_comp._active=true;
        select_Computers(_id);
        
        
        
        return true;
    }
    
    // DONE
    
    
    function getSelectedComputerByPosition(bytes32 _computationId, uint num) public view returns (address) {
        
        return _computations[_computationId]._selectedComputers[num];
    }
    function getReputation(address _computer) public view returns (uint256) {
        
        return _reputations[_computer];
    }
    function getComputerResponsesByAddress(bytes32 _computationId, address _comp) public view returns (uint256) {
        
        return _computations[_computationId]._responses[_comp];
    }
    
    function Submit_Result(bytes32 _computationId, uint256 _response) public returns (bool) {
        require(
            _computations[_computationId]._startingBlock>0,
            "Submit Result: Computation doesn't exist"
        );
        
        require(
            computer_was_selected(_computationId),
            "Computer wasn't selected"
        );
        require(
            _computations[_computationId]._responses[msg.sender]==0,
            "Only one submission allowed per computer"
        );
        _computations[_computationId]._responses[msg.sender]=_response;
	
	// give the block producer an increase in reputation. See Reputation Mechanism section of paper for further details.
	
	_reputations[address(block.coinbase)]+= uint256(_repMultiplier*_computations[_computationId]._numToReward/_computations[_computationId]._numToSelect);
        return true;
    }
    
    // this function, and it's subfunctions require the requester to submit the list of results in order of quality (best to worst)
    function Reveal_Results(bytes32 _computationId, address[] memory _respondingComputers, uint256[] memory _decryptedResults) public returns (bool) {
        require(
            _computations[_computationId]._requester==msg.sender,
            "Reveal Results: Not requester"
        );
        require(
            _computations[_computationId]._active==true,
            "Reveal Results: Computation not active"
        );
        require(
            _respondingComputers.length==_computations[_computationId]._numToSelect,
            "not enough returned computer responses 1"
        );
        require(
            _decryptedResults.length==_computations[_computationId]._numToSelect,
            "not enough returned computer responses 2"
        );
        
        //performs the modular exponentiation of the decryption to power of 3 to verify valid decryption
        for (uint256 j = 0; j < _respondingComputers.length; j++) {
        	uint256 _resultToCheck=_decryptedResults[j];
        	require( _computations[_computationId]._responses[_respondingComputers[j]] ==(_resultToCheck*((_resultToCheck*_resultToCheck)%_computations[_computationId]._publicKeyN)) %_computations[_computationId]._publicKeyN,
            	"not a valid decryption"
        	);   		
        }
        // in this basic encoding, we only have one target function. This can be expanded.
        if (_computations[_computationId]._targetFunctionID==1){
        	require(rewardSetCheck_targetFunction1(_computationId, _respondingComputers, _decryptedResults),"reward set is incorrect");
        }
        // distribute rewards and update reputations
	
	
        for (uint256 j = 0; j < _computations[_computationId]._numToReward; j++) {
            payable(_respondingComputers[j]).transfer(_computations[_computationId]._rewardAmount);
            _reputations[_respondingComputers[j]]+=(1*_repMultiplier);		
        }
	
	// update the reputation of the block producer in line with reputation mechanism of the paper
	_reputations[address(block.coinbase)]+= (_repMultiplier*_computations[_computationId]._numToReward);
	
	
        //return escrow to requester
        payable(msg.sender).transfer(_computations[_computationId]._rewardAmount * uint256( _computations[_computationId]._numToReward));
        _computations[_computationId]._active=false;
        return true;
    }
    
    //target function is average
    function rewardSetCheck_targetFunction1(bytes32 _computationId, address[] memory _respondingComputers, uint256[] memory _decryptedResults) internal returns (bool) {
        uint256 targetValue=0;
        for (uint256 j = 0; j < _decryptedResults.length; j++) {
            targetValue += _decryptedResults[j];
            		
        }
        
        targetValue=uint256(DivideBy(targetValue, uint256(_decryptedResults.length)));
        
        uint256 lastDistance=0;
        for (uint256 j = 0; j < _decryptedResults.length; j++) {
            uint256 currentDistance=uint256((int256(targetValue)-int256(_decryptedResults[j]))**2);
            //results were not ordered correctly
            if (currentDistance<lastDistance){
            	return false;
            }
            lastDistance=currentDistance;	
        }
        return true;
    
    }
    
    function computer_was_selected(bytes32 _computationId) internal returns (bool) {
        address _addressToCheck= msg.sender;
        for (uint256 j = 0; j < _computations[_computationId]._selectedComputers.length; j++) {
            if (_computations[_computationId]._selectedComputers[j]==_addressToCheck){
            	return true;
            }		
        }
        return false;
    }
    
    
    
    function select_Computers (bytes32 _computationId) internal {
    	uint256 granularity=1000;
    	address[] memory activeComps= computers;
    	uint256 totalRep;
    	//total balls owned by all players
        uint256 upperbound;
        //select ball by modulo randomness by number of balls
        uint256 selectedBall;
        	
        uint256 currentTotal;
        uint256 currentComputer;
    	
    	
    	for (uint256 i = 0; i < _computations[_computationId]._numToSelect; i++){
    		
    		totalRep=0;
    		
    		for (uint256 j = 0; j < computers.length-(i+1); j++) {
            		totalRep+=_reputations[activeComps[j]];
            		
        	}
        	//total balls owned by all players
        	upperbound =totalRep * granularity;
        	//select ball by moduloing randomness by number of balls
        	refreshRandomness();
        	selectedBall=uint256(_randomness)%upperbound;
        	
        	currentTotal=0;
        	currentComputer=0;
        	//iterate through computers based on reputation
        	while (currentTotal<=selectedBall){
        		currentTotal+= (_reputations[activeComps[currentComputer]]*granularity);
        		currentComputer++;
        	}
        	_computations[_computationId]._selectedComputers.push( activeComps[currentComputer-1]);
        	if (currentComputer<computers.length-(i+1)){
        		for (uint256 j = currentComputer-1; j < activeComps.length-(i+1); j++) {
            			activeComps[j]=activeComps[j+1];
            		
        		}
        	}
    	} 
    }
    

    
    function DivideBy(uint256 numerator, uint256 denominator)
        internal
        pure
        returns (uint256)
    {
        return SafeMath.div(numerator, denominator);
    }

    
    

    // proceeding functions return various pieces of information that should be checked
    // BEFORE interacting with the blockchain

    // check if registration ID exists



    function _getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function _getPlayerBalance() public view returns (uint256) {
        return msg.sender.balance;
    }

    


}
