// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <=0.9.0;
// pragma solidity ^0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    uint256 private enabled = block.timestamp;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint256 private constant MULTI_CONSENSUS_COUNT = 1;

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    address[] multiConsensus = new address[](0);

    struct AirlineFlight {
        string flight;
        bool isRegistered;
        uint8 statusCode;
        uint256 flightTimestamp;
        address airline;
        string from;
        string to;
    }

    struct Airline {
        string name;
        bool hasPaid;
        bool isRegistered;
    }

    struct Insurance {
        address passenger;
        uint256 amount;
        uint256 multiplier;
        bool isCredited;
    }

    mapping(address => uint256) private authorizedContracts;
    mapping(address => address[]) private registeredAirlinesWithVotes;

    mapping(address => Airline) private airlines;
    mapping(bytes32 => AirlineFlight) private flights;
    mapping(bytes32 => Insurance[]) passengersInsurancePerFlight;
    mapping(address => uint256) public pendingPayments;


    address[] registeredAirlines = new address[](0);
    bytes32[] registeredFlights = new bytes32[](0);

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    //PVM 28/11/2021
    event AirlinePaid(string name, address addr);
    event AirlineRegistered(string name, address addr);
    event InsuranceCredited(address passenger, uint256 amount);
    event InsuranceBought(address airline, string flight, uint256 timestamp, address passenger, uint256 amount, uint256 multiplier);
    event FlightStatusUpdated(address airline, string flight, uint256 timestamp, uint8 statusCode);
    event AccountWithdrawal(address passenger, uint256 amount);
    event FlightRegistered(address airline, string flight, string from, string to, uint256 timestamp);


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    //string memory firstAirlineName,
    */
    constructor
                                (
                                    
                                ) 
                                public 
    {
        contractOwner = msg.sender;

        airlines[contractOwner] = Airline({
            name: "firstAirlineName", //firstAirlineName,
            hasPaid: false,
            isRegistered: true
        });

        registeredAirlines.push(contractOwner);
    }

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
        require(operational, "Contract is currently not operational");
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

    modifier requireHasAirlinePaid(address airline){
        require(
            this.isPaidAirline(airline),
            "Only existing paid airlines are allowed to participate"
        );
        _;
    }

    modifier requireIsContractAuthorized(){
        require(
            authorizedContracts[msg.sender] == 1,
            "Not an authorized contract"
        );
        _;
    }

    modifier requireValidAddress(address addr){
        require(
            addr != address(0),
            "require a valid address"
        );
        _;
    }

    modifier requireIsAirlineRegistered(address addr){
        require(
            !airlines[addr].isRegistered,
            "Airline hs already been registered"
        );
        _;
    }

    modifier requirePendingPaymentAmount(address passenger){
        require(
            pendingPayments[passenger] > 0,
            "Fund is not enough for withdrawal"
        );
        _;
    }

    modifier isDuplicatedCall(){
        bool isDuplicated = false;

        for(uint256 x = 0; x < multiConsensus.length; x++){
            if(multiConsensus[x] == msg.sender){
                isDuplicated = true;
                break;
            }
        }

        require(!isDuplicated, "Caller has already called this function");
        _;
    }



    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            isDuplicatedCall
                            requireContractOwner 
    {
        operational = mode;
    }

    //PVM 28/11/2021
    function authorizeCaller
                            (
                            address contractAddress
                            )
                            public
                            requireContractOwner
    {
        authorizedContracts[contractAddress] = 1;
    }

    function deauthorizeCaller
                            (
                            address contractAddress
                            )
                            public
                            requireContractOwner
    {
        delete authorizedContracts[contractAddress];
    }

    function getAirlineName
                            (
                                address airline
                            )
                            external
                            view
                            returns (string memory)
    {
        return airlines[airline].name;
    }

    function isRegisteredAirline
                            (
                                address airline
                            )
                            external
                            view
                            returns(bool)
    {
        return airlines[airline].isRegistered;
    }

    function isPaidAirline
                            (
                                address airline
                            )
                            external
                            view
                            returns(bool)
    {
        return airlines[airline].hasPaid;
    }

    function getRegisteredAirlines
                                (

                                )
                                external
                                view
                                returns(address[] memory)
    {
        return registeredAirlines;
    }

    function isInsured
                    (
                        bytes32 key, 
                        address passenger
                    )
                    external
                    view
                    returns(bool)
    {
        Insurance[] memory insuredPassengers = passengersInsurancePerFlight[key];

        for(uint x = 0; x < insuredPassengers.length; x++){
            if(insuredPassengers[x].passenger == passenger){
                return true;
            }
        }

        return false;
    }

    function isRegisteredFlight
                            (
                                bytes32 key
                            )
                            external 
                            view 
                            returns(bool)
    {
        return flights[key].isRegistered;
    }

    function getPendingPaymentAmount
                                (
                                    address passenger
                                )
                                external 
                                view 
                                returns(uint256)
    {
        return pendingPayments[passenger];
    }


    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    // pure
    function registerAirline
                            (   
                                string calldata name,
                                address addr
                            )
                            external
                            requireIsOperational
                            requireIsContractAuthorized
                            requireValidAddress(addr)
                            requireIsAirlineRegistered(addr)
                            returns (bool success)                            
    {
        airlines[addr] = Airline({
            name: name,
            hasPaid: false,
            isRegistered: true
        });


        emit AirlineRegistered(name, addr);
        return true;
    }

    function isAirline
                    (
                        address addr
                    )
                    external
                    view 
                    requireIsContractAuthorized
                    returns(bool)
    {
        return airlines[addr].isRegistered;
    }

    function payAirline
                    (
                        address addr
                    )
                    external
                    requireIsOperational 
                    requireIsContractAuthorized
    {
        airlines[addr].hasPaid = true;

        emit AirlinePaid(airlines[addr].name, addr);
    }

    function registerFlight
                        (
                            address airline,
                            string calldata flight,
                            string calldata from,
                            string calldata to,
                            uint256 timestamp,
                            bytes32 key
                        )
                        external
                        requireIsOperational
                        requireIsContractAuthorized
                        requireValidAddress(airline)
                        requireHasAirlinePaid(airline)
    {
        require(
            !flights[key].isRegistered,
            "This flight has been already registered"
        );

        flights[key] = AirlineFlight({
            flight: flight,
            isRegistered: true,
            statusCode: 0,
            flightTimestamp: timestamp,
            airline: airline,
            from: from,
            to: to
        });

        registeredFlights.push(key);

        emit FlightRegistered(airline, flight, from, to, timestamp);
    }

    function processFlightStatus
                            (
                                address airline,
                                string calldata flight,
                                uint256 timestamp,
                                uint8 statusCode
                            )
                            external
                            requireIsOperational
                            requireIsContractAuthorized
    {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);

        if(flights[flightKey].statusCode == STATUS_CODE_UNKNOWN){
            flights[flightKey].statusCode = statusCode;
            if(statusCode == STATUS_CODE_LATE_AIRLINE){
                creditInsurees(flightKey);
            }
        }
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (
                                bytes32 flightKey,
                                address passenger,
                                uint256 amount,
                                uint256 multiplier                             
                            )
                            external
                            payable
                            requireIsOperational
                            requireIsContractAuthorized
    {

        passengersInsurancePerFlight[flightKey].push(
            Insurance({
                isCredited: false,
                amount: amount,
                multiplier: multiplier,
                passenger: passenger
            })
        );
    }

    /**
     *  @dev Credits payouts to insurees
        external
        pure
    */
    function creditInsurees
                                (
                                    bytes32 flightKey
                                )
                                internal
                                requireIsOperational
                                requireIsContractAuthorized
    {
        for(uint256 x = 0; x < passengersInsurancePerFlight[flightKey].length; x++){
            Insurance memory insurance = passengersInsurancePerFlight[flightKey][x];
        

            if(insurance.isCredited == false){
                insurance.isCredited = true;

                uint256 amount = insurance.amount.mul(insurance.multiplier).div(100);

                pendingPayments[insurance.passenger] += amount;

                emit InsuranceCredited(insurance.passenger, amount);
            }
        }
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                                address payable passenger
                            )
                            external
                            requireIsOperational
                            requireIsContractAuthorized
                            requirePendingPaymentAmount(passenger)
    {
        uint256 amount = pendingPayments[passenger];
        pendingPayments[passenger] = 0;
        address(uint160(passenger)).transfer(amount);

        emit AccountWithdrawal(passenger, amount);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (   
                            )
                            public
                            payable
    {
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

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    /*
    fallback() 
                            external 
                            payable 
    {
        fund();
    }
    */
    function() external payable {
        fund();
    }


}

