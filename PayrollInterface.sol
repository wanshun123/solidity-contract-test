pragma solidity ^0.4.2;

import './usingOraclize.sol';

interface ExternalToken {
    function totalSupply() constant returns (uint256);
    function balanceOf (address _owner) constant returns (uint256);
    function transfer(address _to, uint256 _value) returns (bool);
}

contract PayrollInterface is usingOraclize { 
    
    address public owner;
    uint public numberOfActiveEmployees;
    uint public numberOfDeletedEmployees;
    uint public totalYearlySalaries;
    
    uint public testingg;
    function testing() returns (uint256) {
        testingg = ExternalToken(allTokenAddresses[1]).totalSupply();
        return ExternalToken(allTokenAddresses[1]).totalSupply();
    }

    function PayrollInterface() {
        oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);
        owner = msg.sender;
    }
    
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
    
    struct Employee {
        address accountAddress;
        uint256[] distribution;
        uint256 yearlyEURSalary;
        uint256 timeCreated;
        uint256 lastAllocationChangeTime;
        uint256 lastPaidTime;
    }
    
    mapping (uint => Employee) private employees;
    
    // if the contract allowed an employee to set any token contract address to be paid in there would be all kinds of issues (would have to validate if the contract address is for a legitimate ERC20 token, whether there is an exchange rate for it in Kraken, and whether those tokens can even be brought etc), for practical purposes there should just be a small list of token contract addresses set by the owner that are allowed to be used, then when setting how an employee is paid a simple distrubution[] array is kept that says what percent of employees pay goes to each token. For this example setting a max of 3 tokens
    // ETH itself doesn't have a token contract address, for that this contract address can be entered, ie. address(this)
    
    // for testing purposes allTokenAddresses[1] and allTokenAddresses[2] are token addresses for tokens called LTC and XRP that I've deployed on rinkeby using icocompiler.com
    address[] public allTokenAddresses = [address(this), 0x0a6ebb3690b7983e470D3aBFB86636cf64925B98, 0xAeCbB7a5017587046D55dc68928544B81c1A3b35];
    
    // the bytes32[] array below is "ETH", "LTC" and "XMR" in bytes32, as commented below Solidity doesn't allow an array of strings so it has to be like this then converted to a string when needed
    bytes32[] public allTokenSymbols = [bytes32(0x4554480000000000000000000000000000000000000000000000000000000000), bytes32(0x4c54430000000000000000000000000000000000000000000000000000000000),bytes32(0x584d520000000000000000000000000000000000000000000000000000000000)];    
        
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
    // newAllowedTokenAddresses[x] would be the address for the token symbol _allTokenSymbols[x]
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

    function addEmployee (address accountAddress, uint256[] distribution, uint256 yearlyEURSalary) onlyOwner {

        // distribution[x] is the percentage of the employees salary paid in the token at address allTokenAddresses[x], so if the employee only wanted to be paid in ETH it might just be [100, 0, 0] for example

        require(distribution.length == allTokenAddresses.length);

        uint totalDistribution;
        for (uint i = 0; i < distribution.length; i++) {
            totalDistribution = totalDistribution + distribution[i];
        }
        require(totalDistribution == 100);
        
        employees[numberOfActiveEmployees + numberOfDeletedEmployees].accountAddress = accountAddress;
        employees[numberOfActiveEmployees + numberOfDeletedEmployees].distribution = distribution;
        employees[numberOfActiveEmployees + numberOfDeletedEmployees].yearlyEURSalary = yearlyEURSalary;
        employees[numberOfActiveEmployees + numberOfDeletedEmployees].timeCreated = now;
        numberOfActiveEmployees++;
        totalYearlySalaries = totalYearlySalaries + yearlyEURSalary;
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
        // fallback function
    }
    
    bool public isPaused;
    
    function scapeHatch() onlyOwner {
        // no instructions on what this is supposed to do exactly, assuming it's a function to halt the contract from sending out tokens
        if (isPaused = false) {
            isPaused = true;
        } else {
            isPaused = false;
        }
    }
    
    function addTokenFunds() onlyOwner {
        // is this necessary? function isn't required for the contract to receive tokens, anyone can still transfer an ERC20 token to a contract address by calling the transfer() function of an ERC20 token
        // Use approveAndCall or ERC223 tokenFallback 
    }
    
    function getEmployeeCount() onlyOwner constant returns (uint256) {
        return numberOfActiveEmployees;
    }
    
    function getEmployee (uint256 employeeId) onlyOwner constant returns (address, uint256[], uint256, uint256, uint256, uint256) {
        // Return all info 
        return (employees[employeeId].accountAddress, employees[employeeId].distribution, employees[employeeId].yearlyEURSalary, employees[employeeId].timeCreated, employees[employeeId].lastAllocationChangeTime, employees[employeeId].lastPaidTime);
    }
    
    function calculatePayrollBurnrate() onlyOwner constant returns (uint256) {
        // Monthly EUR amount spent in salaries 
        return totalYearlySalaries/12;
    }
    
    uint public latestETHPayrollRunway;
    bool public calculateETHRunwayInProgress;
    function calculateETHPayrollRunway() payable onlyOwner {
        // Days until the contract can run out of funds - only takes into account ETH balance. If employees wanted to be paid in different tokens and the contract only has ETH this function wouldn't be suitable
        // get the current value of ETH in Euro's. setExchangeRate("ETH") updates the value of latestExchangeRate, then in the callback oraclize function it'll call returnETHPayrollRunway() to return the latestETHPayrollRunway value. Has to be done like this as Solidity doesn't wait for setExchangeRate("ETH") to finish before moving to the next line
        calculateETHRunwayInProgress = true;
        setExchangeRate("ETH");
    } 
    
    function returnETHPayrollRunway() onlyOwnerOrOraclize returns (uint256) {
        uint256 totalDailySalaries = totalYearlySalaries/365;
        uint256 contractBalanceInEuro = this.balance * latestExchangeRate;
        // a this.balance of 1 Ether would return 1 * 10^18
        latestETHPayrollRunway = (contractBalanceInEuro/totalDailySalaries)/10**18;
        return latestETHPayrollRunway;
    }
    
    uint public tokenAt = 0;
    uint public latestAllTokensPayrollRunway;
    uint public totalEURBalanceAllTokens;
    bool public calculateAllTokensRunwayInProgress;
    bool public allTokensETHinProgress;
   //  uint[] public exchangeRatesTokens;
    
    uint public tokenAt2 = 0;
    
    mapping (uint => uint) public exchangeRatesTokens;
    mapping (uint => uint) public tokenBalances;
    
    function calculatePayrollRunwayIncludingAllTokens() payable onlyOwner {
        // this will calculate the value in Euro's of any other tokens in the allTokenSymbols[] array the contract may own, in addition to ETH - then compare the value of all that to the salary in Euro of all employees. Will take some time as it has to query kraken for the exchange rate of each token
        // as with the calculateETHPayrollRunway() function, this is split into 2 functions, one to query oraclize and then one to process the result
        calculateAllTokensRunwayInProgress = true;
        tokenAt = 0;
        for (tokenAt = 0; tokenAt < allTokenAddresses.length; tokenAt++) {
            if (allTokenAddresses[tokenAt] != address(this)) {
                // ERC20 token other than ETH. Get the token symbol and query kraken to see the value of this token in Euro's, then returnAllTokensPayrollRunway() below will be callsed which finds the how many tokens this contract owns and their value in Euro's
                // queries executed 30 seconds apart
                tokenBalances[tokenAt] = ExternalToken(allTokenAddresses[tokenAt]).balanceOf(address(this));
                string memory token = bytes32ToString(allTokenSymbols[tokenAt]);
                // setExchangeRate(token);
                oraclize_query(30 * tokenAt, "URL", strConcat("json(https://api.kraken.com/0/public/Ticker?pair=", token,"EUR).result.X", token,"ZEUR.c.0"), 500000);
            } else {
                tokenBalances[tokenAt] = this.balance;
                allTokensETHinProgress = true;
                oraclize_query(30 * tokenAt, "URL", strConcat("json(https://api.kraken.com/0/public/Ticker?pair=ETHEUR).result.XETHZEUR.c.0"), 500000);
            }
        }
    }
    
    uint public testingyall = allTokenAddresses.length;
    
    function returnAllTokensPayrollRunway() onlyOwnerOrOraclize {
        
        if (allTokensETHinProgress) {
            allTokensETHinProgress = false;
            uint256 contractBalanceInEuroETH = this.balance * exchangeRatesTokens[tokenAt2];
            totalEURBalanceAllTokens = totalEURBalanceAllTokens + contractBalanceInEuroETH;
        } else {
            // uint256 tokenBalance = ExternalToken(allTokenAddresses[tokenAt2]).balanceOf(address(this));
            uint256 contractBalanceInEuroERC20Token = tokenBalances[tokenAt2] * exchangeRatesTokens[tokenAt2];
            totalEURBalanceAllTokens = totalEURBalanceAllTokens + contractBalanceInEuroERC20Token;
        }
        
        if (tokenAt2 == allTokenAddresses.length - 1) {
            // done for all tokens
            calculateAllTokensRunwayInProgress = false;
            uint256 totalDailySalaries = totalYearlySalaries/365;
            latestAllTokensPayrollRunway = totalEURBalanceAllTokens/totalDailySalaries;
            totalEURBalanceAllTokens = 0;
        } else {
            tokenAt2++;
        }
        // return latestAllTokensPayrollRunway;
    }
    
    
    
    
    
    /* EMPLOYEE ONLY */ 
    
    function retreiveAllocation (uint256 employeeId) returns (address[], uint256[]) {
        // have a function to let the employee verify their current token allocation, since the getEmployee function can only be called by the contract owner (per project requirements).
        require(employees[employeeId].accountAddress == msg.sender);
        return (allTokenAddresses, employees[employeeId].distribution);
    }

    function determineAllocation (uint256 employeeId, uint256[] distribution) {
        // only callable once every 6 months 
        require(employees[employeeId].accountAddress == msg.sender);
        require(now > employees[employeeId].lastAllocationChangeTime + 180 days);
        // require the distribution array to add up to 100%, same as when an employee is first created
        uint totalDistribution;
        for (uint i = 0; i < distribution.length; i++) {
            totalDistribution = totalDistribution + distribution[i];
        }
        require(totalDistribution == 100);
        employees[employeeId].distribution = distribution;
        employees[employeeId].lastAllocationChangeTime = now;
    } 

    function payday (uint256 employeeId) {
        // only callable once a month 
        if (isPaused) {
            revert();
        }
        require(employees[employeeId].accountAddress == msg.sender);
        require(now > employees[employeeId].lastPaidTime + 30 days);
        uint256 employeeSalary = employees[employeeId].yearlyEURSalary;
        for (uint i = 0; i < allTokenAddresses.length; i++) {
            uint256 distribution = employees[employeeId].distribution[i];
            uint256 valueOfTokenInEuro = (employeeSalary * distribution)/100;
            if (allTokenAddresses[i] == address(this)) {
                // ETH
                setExchangeRate('ETH');
                uint256 amountOfETHToTransfer = valueOfTokenInEuro / latestExchangeRate;
                msg.sender.transfer(amountOfETHToTransfer);
            } else {
                // ERC20 token. Similar to the calculatePayrollRunwayIncludingAllTokens(), get the token symbol and the exchange rate of the tokens in Euro's. Then call the transfer() function in that token contract to send the right amount of tokens to the employee
                bytes32 tokenBytes32 = allTokenSymbols[i];
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
    
    uint256 public latestExchangeRate;

    function __callback (bytes32 myid, string result, bytes proof) {
        if (msg.sender != oraclize_cbAddress()) throw;
        latestExchangeRate = parseInt(result);
        newOraclizeQuery("Result returned");
        
        if (calculateETHRunwayInProgress) {
            calculateETHRunwayInProgress = false;
            returnETHPayrollRunway();
        } else if (calculateAllTokensRunwayInProgress) {
            // calculateAllTokensRunwayInProgress = false;
            // exchangeRatesTokens.push(latestExchangeRate);
            exchangeRatesTokens[tokenAt2] = latestExchangeRate;
            returnAllTokensPayrollRunway();
        }
        
    }
    
    function setExchangeRate (string symbol) payable onlyOwnerOrOraclize {
        // the symbol parameter will be the token symbol like ETH, BTC, LTC. Then this will find the value of that token in Euro's.
        if (oraclize_getPrice("URL") > this.balance) {
            newOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {
            newOraclizeQuery("Oraclize query was sent, standing by for the answer..");
            // the symbol parameter is concatenated into the oraclize query below
            oraclize_query("URL", strConcat("json(https://api.kraken.com/0/public/Ticker?pair=", symbol,"EUR).result.X", symbol,"ZEUR.c.0"));
        }
    }
    
}
