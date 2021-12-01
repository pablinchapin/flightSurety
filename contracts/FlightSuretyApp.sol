// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <=0.9.0;
// pragma solidity ^0.4.24;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FlightSuretyData.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    FlightSuretyData flightSuretyData;

    bool private operational = true;

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    uint256 private constant AIRLINE_FUND = 10 ether;
    uint256 private constant AIRLINE_LIMIT = 4;
    uint256 private constant AIRLINE_FEE = 1 ether;
    uint256 private constant INSURANCE_MAX_VALUE = 1 ether;
    uint256 private constant AGREEMENT_DIVIDER = 2;
    
    address payable private contractOwner;          // Account used to deploy contract

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
    }
    mapping(bytes32 => Flight) private flights;

    mapping(address => address[]) private votedRegisteredAirlines;

 
    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        //PVM
        // Modify to call data contract's status
        require(flightSuretyData.isOperational(), 
                "Contract is currently not operational"
        );  
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }


    //PVM 28/11/2021
    modifier requireAirlinePayment(address addr)
    {
        require(flightSuretyData.isPaidAirline(addr),
        "Only allowed to paid airlines" );
        _;
    }

    modifier requireAirlineUnique(address addr)
    {
        bool unique = true;

        for(uint256 x = 0; x < votedRegisteredAirlines[addr].length; x++){
            if(votedRegisteredAirlines[addr][x] == msg.sender){
                unique = false;
                break;
            }
        }

        require(unique, "Airline already registered.");
        _;
    }

    modifier requireValidAddress(address addr){
        require(addr != address(0), "Address invalid");
        _;
    }

    modifier requireFee(){
        require(msg.value == AIRLINE_FUND, "Invalid value submitted");
        _;
    }

    modifier requireInsuranceFee(){
        require(
            msg.value > 0 && msg.value < INSURANCE_MAX_VALUE,
            "Wrong insurance value"
        );
        _;
    }

    modifier requireFlightRegistration(
        address addr,
        string memory flight,
        uint256 timestamp
    ){
        require(
            flightSuretyData.isRegisteredFlight(
                getFlightKey(addr, flight, timestamp)
            ),
            "Flight is not registered"
        );
        _;
    }

    modifier requirePassenger(
        string memory flight,
        uint timestamp
    ){
        require(
            flightSuretyData.isInsured(
                getFlightKey(msg.sender, flight, timestamp),
                msg.sender
            ),
            "Passenger already bought this insurance"
        );
        _;
    }


    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    // address contractData
    */
    constructor
                                (
                                    
                                )
                                public
                                
    {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(contractOwner);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/
    //pure 
    function isOperational() 
                            public view
                            
                            returns(bool) 
    {
        return operational;// true;  // Modify to call data contract's status
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline
                            (   
                                string memory name,
                                address addr
                            )
                            public
                            requireValidAddress(addr)
                            requireAirlinePayment(msg.sender)
                            requireIsOperational
                            requireAirlineUnique(addr)
                            
                            returns(bool success, uint256 votes)
    {

        bool result = false;

        address[] memory registeredAirlines = flightSuretyData.getRegisteredAirlines();

        if( registeredAirlines.length == 0 || registeredAirlines.length < AIRLINE_LIMIT ){
            result = flightSuretyData.registerAirline(name, addr);
        }else{
                votedRegisteredAirlines[addr].push(msg.sender);

                if( votedRegisteredAirlines[addr].length >= registeredAirlines.length.div(AGREEMENT_DIVIDER) ){
                        result = flightSuretyData.registerAirline(name, addr);

                        votedRegisteredAirlines[addr] = new address[](0);
                }
        }
        
        //PVM nned to confirm if this return value is ever used
        //return (success, 0);
        return (result, votedRegisteredAirlines[addr].length);
    }


   /**
    * @dev Register a future flight for insuring.
    *
    */  
    //pure
    function registerFlight
                                (
                                    string calldata flight,
                                    string calldata from,
                                    string calldata to,
                                    uint256 timestamp
                                )
                                external 
                                requireIsOperational
                                requireValidAddress(msg.sender)
                                requireAirlinePayment(msg.sender)

                                
    {
        bytes32 flightKey = getFlightKey(msg.sender, flight, timestamp);
        flightSuretyData.registerFlight(msg.sender, flight, from, to, timestamp, flightKey);

    }
    
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    //pure
    function processFlightStatus
                                (
                                    address airline,
                                    string memory flight,
                                    uint256 timestamp,
                                    uint8 statusCode
                                )
                                internal
                                
    {

        /**
        if(statusCode == STATUS_CODE_LATE_AIRLINE){
            //flightSuretyData.creditInsurees();
        }
        */

        flightSuretyData.processFlightStatus(airline, flight, timestamp, statusCode);

    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
                        (
                            address airline,
                            string calldata flight,
                            uint256 timestamp                            
                        )
                        external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    } 

    //PVM 28/11/2021
    function getPendingPaymentAmount(address passengerAddr)
        external
        view
        returns(uint256)
    {
        return flightSuretyData.getPendingPaymentAmount(passengerAddr);
    }

    function refund() 
        external 
        requireIsOperational
    {
        return flightSuretyData.pay(msg.sender);        
    }


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3] memory)
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string calldata flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3] memory)
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }


    function() external payable {}
// endregion
}