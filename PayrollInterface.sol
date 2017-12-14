pragma solidity ^0.4.2;

import './usingOraclize.sol';

interface ExternalToken {
    function totalSupply() constant returns (uint256);
    function balanceOf (address _owner) constant returns (uint256);
    function transfer(address _to, uint256 _value) returns (bool);
}

contract PayrollInterface is usingOraclize { 
    
    address owner;
    uint private numberOfActiveEmployees;
    uint private numberOfDeletedEmployees;
    uint private totalYearlySalaries;

    function PayrollInterface() {
        owner = msg.sender;
        allTokenSymbols.push("ETH");
        allTokenSymbols.push("LTC");
        allTokenSymbols.push("XRP");
    }
    
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
    
    struct Employee {
        address accountAddress;
        address[] allowedTokens;
        uint256[] distribution;
        uint256 yearlyEURSalary;
        uint256 timeCreated;
        uint256 lastAllocationChangeTime;
        uint256 lastPaidTime;
    }
    
    mapping (uint => Employee) private employees;
    
    // if the contract allowed an employee to set any token contract address to be paid in, an array of all the different token addresses that different employees have elected to be paid in would need to be maintained which would get cumbersome and there would be all kinds of issues (would have to validate if the contract address is for a legitimate ERC20 token, whether there is an exchange rate for it in Kraken, and whether those tokens can even be brought etc), for practical purposes there should just be a small list of token contract addresses that are allowed to be used. For this example setting a max of 3
    // ETH itself doesn't have a token contract address, for that this contract address can be entered, ie. address(this)
    
    // for testing purposes allTokenAddresses[1] and allTokenAddresses[2] are token addresses for tokens called LTC and XRP that I've deployed on rinkeby
    address[] allTokenAddresses = [address(this), 0x0a6ebb3690b7983e470D3aBFB86636cf64925B98, 0x38206cAb32b67F33F07ac7df984127975120Ee09];
    
    // the bytes32[] array below is "ETH", "LTC" and "XRP" in bytes32 (these are added to this array in the constructor function when the contract is created), as commented below Solidity doesn't allow an array of strings so it has to be like this then converted to a string when needed
    bytes32[] public allTokenSymbols;
    // bytes32[] public allTokenSymbols = ["0x4554480000000000000000000000000000000000000000000000000000000000", "0x4c54430000000000000000000000000000000000000000000000000000000000", "0x5852500000000000000000000000000000000000000000000000000000000000"];
    
    function bytes32ToString(bytes32 x) constant returns (string) {
    bytes memory bytesString = new bytes(32);
    uint charCount = 0;
    for (uint j = 0; j < 32; j++) {
        byte char = byte(bytes32(uint(x) * 2 ** (8 * j)));
        if (char != 0) {
            bytesString[charCount] = char;
            charCount++;
        }
    }
    bytes memory bytesStringTrimmed = new bytes(charCount);
    for (j = 0; j < charCount; j++) {
        bytesStringTrimmed[j] = bytesString[j];
    }
    return string(bytesStringTrimmed);
    }
    
    // have to have the token symbols stored for when kraken is called to get the value of that token in Euro's, it's not guaranteed an ERC20 token will have a symbol of type string specified in its contract so let the owner state what the symbol is. Has to be an array of bytes32 which will then be converted to a string via the bytes32ToString() function, since Solidity doesn't allow an array of variable length strings
    // newAllowedTokenAddresses[0] would be the address for the token symbol _allTokenSymbols[0]
    // would have to be very careful about changing allowed tokens after there are already employees created who are setup to be paid in different tokens, as paying them after that would fail
    function adjustAllowedTokenAddresses (address[] newAllowedTokenAddresses, bytes32[] _allTokenSymbols) onlyOwner {
        require(newAllowedTokenAddresses.length < 4);
        require(newAllowedTokenAddresses.length == _allTokenSymbols.length);
        // check if these token addresses are legit ERC20 tokens
        for (uint i = 0; i < newAllowedTokenAddresses.length; i++) {
            if (newAllowedTokenAddresses[i] == address(this)) {
                // one of the tokens is ETH, fine, move on
            } else {
                // try calling totalSupply() which is a required ERC20 token function, could also try calling some other ERC20 functions and oraclize to see if kraken has an exchange rate for the symbol (that would take the symbol from the _allTokenSymbols[] array). ExternalToken is the interface defined at the top. Of course just having a totalSupply() function doesn't guarantee it's a valid ERC20 token but it's good enough for this example. This will be required for the token address to be accepted. 
                uint256 totalSupplyTest = ExternalToken(newAllowedTokenAddresses[i]).totalSupply();
                require(totalSupplyTest > 0);
            }
        }
        allTokenAddresses = newAllowedTokenAddresses;
        allTokenSymbols = _allTokenSymbols;
    }

    function addEmployee (address accountAddress, address[] allowedTokens, uint256[] distribution, uint256 yearlyEURSalary) onlyOwner {
        // There is the determineAllocation function that lets an employee set how they are paid in different tokens, so this should also be set when an employee is created
        // Going off how the determineAllocation function was written in the project description have two separate arrays for the tokens employee is paid in, and the % of their salary paid in that token - distribution[0] would be the % of the employees salary paid in the allowedTokens[0] token
        require(allowedTokens.length < 4);
        require(allowedTokens.length == distribution.length);
        // require the distribution array to add up to 100%, and check if the token addresses this employee will be paid in exist in allTokenAddresses[] - won't use much gas with these loops since there will only be a handful of allowed tokens and the arrays will be very small
        uint totalDistribution;
        for (uint i = 0; i < distribution.length; i++) {
            totalDistribution = totalDistribution + distribution[i];
        }
        require(totalDistribution == 100);
        // if there wasn't a max number of tokens allowed (3) hardcoded the below would be a loop within a loop, it would be tedious if there were a huge number of tokens in allTokenAddresses[] as there isn't an efficient way of searching an array in Solidity and gas will run out looping through it. Again it is just a practical decision to limit to 3 tokens employees can be paid in.
        for (uint j = 0; j < allowedTokens.length; j++) {
            require(allowedTokens[i] == allTokenAddresses[0] || allowedTokens[i] == allTokenAddresses[1] || allowedTokens[i] == allTokenAddresses[2]);
        }
        employees[numberOfActiveEmployees + numberOfDeletedEmployees].accountAddress = accountAddress;
        employees[numberOfActiveEmployees + numberOfDeletedEmployees].allowedTokens = allowedTokens;
        employees[numberOfActiveEmployees + numberOfDeletedEmployees].distribution = distribution;
        employees[numberOfActiveEmployees + numberOfDeletedEmployees].yearlyEURSalary = yearlyEURSalary;
        employees[numberOfActiveEmployees + numberOfDeletedEmployees].timeCreated = now;
        numberOfActiveEmployees++;
        totalYearlySalaries = totalYearlySalaries + employees[numberOfActiveEmployees + numberOfDeletedEmployees].yearlyEURSalary;
    }
    
    function setEmployeeSalary (uint256 employeeId, uint256 yearlyEURSalary) onlyOwner {
        require(yearlyEURSalary > 0);
        totalYearlySalaries = totalYearlySalaries - employees[employeeId].yearlyEURSalary + yearlyEURSalary;
        employees[employeeId].yearlyEURSalary = yearlyEURSalary;
    }
    
    function removeEmployee (uint256 employeeId) onlyOwner {
        totalYearlySalaries = totalYearlySalaries - employees[employeeId].yearlyEURSalary;
        delete employees[employeeId];
        numberOfActiveEmployees--;
        numberOfDeletedEmployees++;
    }
    
    function addFunds() payable onlyOwner {
        // unnecessary, simplest is to just have a fallback function() that's payable that'll accept Ether if someone sends it to the contract address without calling a function as below
        // if there has to be an addFunds() function, nothing is needed in it, the function could be executed and Ether sent in Geth as follows:
        // thisContractInstance.addFunds({from: web3.eth.accounts[0], value: web3.toWei(0.1, "ether")})
    }
    
    function() payable {
        
    }
    
    function scapeHatch() onlyOwner {
        // unclear what this is supposed to do
    }
    
    function addTokenFunds() onlyOwner {
        // is this necessary? function isn't required for the contract to receive tokens, anyone can still transfer an ERC20 token to a contract address
        // Use approveAndCall or ERC223 tokenFallback 
    }
    
    function getEmployeeCount() onlyOwner constant returns (uint256) {
        return numberOfActiveEmployees;
    }
    
    function getEmployee (uint256 employeeId) onlyOwner constant returns (address, address[], uint256[], uint256, uint256, uint256, uint256) {
        // Return all info 
        return (employees[employeeId].accountAddress, employees[employeeId].allowedTokens, employees[employeeId].distribution, employees[employeeId].yearlyEURSalary, employees[employeeId].timeCreated, employees[employeeId].lastAllocationChangeTime, employees[employeeId].lastPaidTime);
    }
    
    function calculatePayrollBurnrate() onlyOwner constant returns (uint256) {
        // Monthly EUR amount spent in salaries 
        return totalYearlySalaries/12;
    }
    
    function calculatePayrollRunway() onlyOwner constant returns (uint256) {
        // Days until the contract can run out of funds - only takes into account ETH balance. If employees wanted to be paid in different tokens and the contract only has ETH this function wouldn't be suitable
        uint256 totalDailySalaries = totalYearlySalaries/365;
        // get the current value of ETH in Euro's
        setExchangeRate('ETH');
        uint256 contractBalanceInEuro = this.balance * latestExchangeRate;
        return contractBalanceInEuro/totalDailySalaries;
    } 
    
    function calculatePayrollRunwayIncludingAllTokens() onlyOwner constant returns (uint256) {
        // this will calculate the value in Euro's of any other tokens in the allTokenSymbols[] array the contract may own, in addition to ETH - then compare the value of all that to the salary in Euro of all employees
        uint256 totalEURbalance;
        uint256 totalDailySalaries = totalYearlySalaries/365;
        for (uint i = 0; i < allTokenAddresses.length; i++) {
            if (allTokenAddresses[i] != address(this)) {
                string memory token = bytes32ToString(allTokenSymbols[i]);
                uint256 tokenBalance = ExternalToken(allTokenAddresses[i]).balanceOf(address(this));
                setExchangeRate(token);
                uint256 contractBalanceInEuroERC20Token = tokenBalance * latestExchangeRate;
                totalEURbalance = totalEURbalance + contractBalanceInEuroERC20Token;
            } else {
                setExchangeRate('ETH');
                uint256 contractBalanceInEuroETH = this.balance * latestExchangeRate;
                totalEURbalance = totalEURbalance + contractBalanceInEuroETH;
            }
        }
        return totalEURbalance/totalDailySalaries;
    }
    
    /* EMPLOYEE ONLY */ 
    
    function retreiveAllocation (uint256 employeeId) returns (address[] tokens, uint256[] distribution) {
        // have a function to let the employee verify their current token allocation, since the getEmployee function can only be called by the contract owner (per project requirements).
        require(employees[employeeId].accountAddress == msg.sender);
        return (employees[employeeId].allowedTokens, employees[employeeId].distribution);
    }

    function determineAllocation (uint256 employeeId, address[] tokens, uint256[] distribution) {
        // only callable once every 6 months 
        require(employees[employeeId].accountAddress == msg.sender);
        require(tokens.length == distribution.length);
        require(now > employees[employeeId].lastAllocationChangeTime + 180 days);
        // require the distribution array to add up to 100% and the tokens the employee wants to be paid in to be in the allTokenAddresses[] array, same as when an employee is first created
        uint totalDistribution;
        for (uint i = 0; i < distribution.length; i++) {
            totalDistribution = totalDistribution + distribution[i];
        }
        require(totalDistribution == 100);
        for (uint j = 0; j < tokens.length; j++) {
            require(tokens[i] == allTokenAddresses[0] || tokens[i] == allTokenAddresses[1] || tokens[i] == allTokenAddresses[2]);
        }
        employees[employeeId].allowedTokens = tokens;
        employees[employeeId].distribution = distribution;
        employees[employeeId].lastAllocationChangeTime = now;
    } 

    function payday (uint256 employeeId) {
        // only callable once a month 
        require(employees[employeeId].accountAddress == msg.sender);
        require(now > employees[employeeId].lastPaidTime + 30 days);
        uint256 employeeSalary = employees[employeeId].yearlyEURSalary;
        for (uint i = 0; i < employees[employeeId].allowedTokens.length; i++) {
            uint256 distribution = employees[employeeId].distribution[i];
            uint256 valueOfTokenInEuro = (employeeSalary * distribution)/100;
            if (employees[employeeId].allowedTokens[i] == address(this)) {
                // ETH
                setExchangeRate('ETH');
                uint256 amountOfETHToTransfer = valueOfTokenInEuro / latestExchangeRate;
                msg.sender.transfer(amountOfETHToTransfer);
            } else {
                bytes32 tokenBytes32;
                if (employees[employeeId].allowedTokens[i] == allTokenAddresses[0]) {
                    tokenBytes32 = allTokenSymbols[0];
                } else if (employees[employeeId].allowedTokens[i] == allTokenAddresses[1]) {
                    tokenBytes32 = allTokenSymbols[1];
                } else if (employees[employeeId].allowedTokens[i] == allTokenAddresses[2]) {
                    tokenBytes32 = allTokenSymbols[2];
                }
                string memory tokenString = bytes32ToString(tokenBytes32);
                setExchangeRate(tokenString);
                uint256 amountOfTokenToTransfer = valueOfTokenInEuro / latestExchangeRate;
                ExternalToken(allTokenAddresses[i]).transfer(msg.sender, amountOfTokenToTransfer);
            }
        }
        employees[employeeId].lastPaidTime = now;
    }

    /* ORACLE ONLY */ 
    
    event newOraclizeQuery(string description);
    
    modifier onlyOwnerOrOraclize {
        require(msg.sender == oraclize_cbAddress() || msg.sender == owner);
        _;
    }
    
    uint256 latestExchangeRate;

    function __callback (string result) {
        if (msg.sender != oraclize_cbAddress()) throw;
        latestExchangeRate = parseInt(result);
        newOraclizeQuery("Result returned");
    }
    
    function setExchangeRate (string symbol) payable onlyOwnerOrOraclize {
        // the symbol parameter will be the token symbol like ETH, BTC, LTC. Then this will find the value of that token in Euro's.
        if (oraclize_getPrice("URL") > this.balance) {
            newOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {
            newOraclizeQuery("Oraclize query was sent, standing by for the answer..");
            oraclize_query("URL", strConcat("json(https://api.kraken.com/0/public/Ticker?pair=", symbol,"EUR).result.X", symbol,"ZEUR.c.0"));
        }
    }
    
    
    
    // function setExchangeRate (address token, uint256 EURExchangeRate); // uses decimals from token 

}
