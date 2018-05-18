pragma solidity ^0.4.21;

import './token/CustomERC20.sol';

contract UpstakeToken is CustomERC20 {
    string public constant name = 'Upstake token';
    string public constant symbol = 'UPS';
    uint8 public constant decimals = 8;
    uint256 public maximumSupply = 2e15;

    /* This unnamed function is called whenever someone tries to send ether to it */
    function() public payable {
        revert();
        // Prevents accidental sending of ether
    }

    /**
    * @dev Function to mint tokens if totalSupply <= maximumSupply
    * @param _to The address that will receive the minted tokens.
    * @param _amount The amount of tokens to mint.
    * @return A boolean that indicates if the operation was successful.
    */
    function mint(address _to, uint256 _amount)  onlyOwner canMint public returns (bool) {
        require(totalSupply.add(_amount) <= maximumSupply);
        return super.mint(_to, _amount);
    }

}
