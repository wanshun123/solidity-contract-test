# solidity-contract-test

This is a contract that will maintain a list of employees and pay them in different ERC20 tokens, including ETH. The owner of the contract can create new employees (setting things such as their annual salary in Euro's, distribution of different ERC20 tokens to be paid in and so on), and employees can also adjust what tokens they are to be paid in and call a function once a month that pays them. To keep this clean employees can only elect to be paid in tokens that have been already approved by the contract owner. Oraclize is used to get the current value of any token that an employee has been set to be paid in in Euro's.

At this stage this is still a work in progress.
