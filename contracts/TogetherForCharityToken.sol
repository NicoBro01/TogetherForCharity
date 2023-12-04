// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TogetherForCharityToken is ERC20 {
    uint256 _totalSupply = 1000000 * (10 ** 18);

    constructor() ERC20("TogetherForCharity", "TFC") {
        _mint(msg.sender, _totalSupply);
    }
}
