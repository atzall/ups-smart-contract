pragma solidity ^0.4.21;


import './IERC20.sol';
import '../ownership/Ownable.sol';
import '../math/SafeMath.sol';


/**
 * @title Mintable token
 * @dev ERC20 Token with mintable token creation
 */

contract CustomERC20 is IERC20, Ownable {

  using SafeMath for uint256;

  bool public mintingFinished = false;
  bool public transferAllowed = false;
  address[] public addressByIndex;
  uint256 public votedHolders;
  uint public refundProcedureStartPercent = 60;

  mapping(address => uint256) private balances;
  mapping (address => mapping (address => uint256)) internal allowed;
  mapping (address => bool) addressAddedToIndex;
  mapping (address => bool) votedHoldersIndividual;

  event Mint(address indexed to, uint256 amount);
  event MintFinished();
  event TransferAllowed(bool);
  event Burn(address indexed burner, uint256 value);

  /* Checking minting bool before mint function execution */
  modifier canMint() {
    require(!mintingFinished);
    _;
  }

  /* Checking minting and transfer allowance bool params before transfer execution */
  modifier canTransfer() {
    require(mintingFinished && transferAllowed);
    _;
  }

  modifier onlyHolders() {
    require(addressAddedToIndex[msg.sender]);
    require(!votedHoldersIndividual[msg.sender]);
    require(balances[msg.sender] > 0);
    _;
  }

  /**
   * @dev Gets the balance of the specified address.
   * @param _owner The address to query the the balance of.
   * @return An uint256 representing the amount owned by the passed address.
   */
  function balanceOf(address _owner) public constant returns (uint256 balance) {
    return balances[_owner];
  }

  /**
   * @dev transfer token for a specified address
   * @param _to The address to transfer to.
   * @param _value The amount to be transferred.
   */
  function transfer(address _to, uint256 _value) canTransfer public returns (bool) {
    require(_to != address(0));
    require(_value <= balances[msg.sender]);
    // SafeMath.sub will throw if there is not enough balance.
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    _addToIndex(_to);
    emit Transfer(msg.sender, _to, _value);
    return true;
  }

  /**
   * @dev Transfer tokens from one address to another
   * @param _from address The address which you want to send tokens from
   * @param _to address The address which you want to transfer to
   * @param _value uint256 the amount of tokens to be transferred
   */
  function transferFrom(address _from, address _to, uint256 _value) canTransfer public returns (bool) {
    require(_to != address(0));
    require(_value <= balances[_from]);
    require(_value <= allowed[_from][msg.sender]);
    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    _addToIndex(_to);
    emit Transfer(_from, _to, _value);
    return true;
  }

  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   *
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   * @param _spender The address which will spend the funds.
   * @param _value The amount of tokens to be spent.
   */
  function approve(address _spender, uint256 _value) public returns (bool) {
    // mitigating the race condition
    assert(allowed[msg.sender][_spender] == 0 || _value == 0);
    allowed[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value);
    return true;
  }

  /**
   * @dev Function to check the amount of tokens that an owner allowed to a spender.
   * @param _owner address The address which owns the funds.
   * @param _spender address The address which will spend the funds.
   * @return A uint256 specifying the amount of tokens still available for the spender.
   */
  function allowance(address _owner, address _spender) public constant returns (uint256 remaining) {
    return allowed[_owner][_spender];
  }

  /**
  * approve should be called when allowed[_spender] == 0. To increment
  * allowed value is better to use this function to avoid 2 calls (and wait until
  * the first transaction is mined)
  * From MonolithDAO Token.sol
  */
  function increaseApproval (address _spender, uint _addedValue) public returns (bool success) {
    allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

  function decreaseApproval (address _spender, uint _subtractedValue) public returns (bool success) {
    uint oldValue = allowed[msg.sender][_spender];
    if (_subtractedValue > oldValue) {
      allowed[msg.sender][_spender] = 0;
    } else {
      allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
    }
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

  /**
   * @dev Function to mint tokens
   * @param _to The address that will receive the minted tokens.
   * @param _amount The amount of tokens to mint.
   * @return A boolean that indicates if the operation was successful.
   */
  function mint(address _to, uint256 _amount) onlyOwner canMint public returns (bool) {
    totalSupply = totalSupply.add(_amount);
    balances[_to] = balances[_to].add(_amount);
    _addToIndex(_to);
    emit Mint(_to, _amount);
    emit Transfer(0x0, _to, _amount);
    return true;
  }

  /**
   * @dev Burns a specific amount of tokens.
   * @param _value The amount of token to be burned.
   */
  function burn(uint256 _value) onlyHolders public {
    _burn(msg.sender, _value);
  }

  function burnFrom(address _address, uint256 _value) onlyOwner public {
    require(getRefundVotes() >= refundProcedureStartPercent);
    _burn(_address, _value);
  }

  function _burn(address _who, uint256 _value) internal {
    require(_value <= balances[_who]);
    balances[_who] = balances[_who].sub(_value);
    totalSupply = totalSupply.sub(_value);
    emit Burn(_who, _value);
    emit Transfer(_who, address(0), _value);
  }

  /**
  * @dev Function to allow token transfers after crowdsale finishing
  * @return True if the operation was successful
  */
  function allowTransfer() onlyOwner public {
    require(mintingFinished);
    transferAllowed = true;
    emit TransferAllowed(transferAllowed);
  }

  /**
   * @dev Function to stop minting new tokens
   * @return True if the operation was successful
   */
  function finishMinting() onlyOwner canMint public returns (bool) {
    mintingFinished = true;
    emit MintFinished();
    return true;
  }

  /**
   * @dev Function to get token holders count
   * @return uint256 addresses count
   */
  function countAddresses() constant public returns (uint256 length) {
    return addressByIndex.length;
  }

  /**
   * Adding address to token holders index
   */
  function _addToIndex(address _indexed) internal {
    if (!addressAddedToIndex[ _indexed]) {
      addressAddedToIndex[ _indexed] = true;
      addressByIndex.push( _indexed);
    }
  }

  /**
   * Refund voting
   */
  function voteToBurn() onlyHolders canTransfer public {
    votedHoldersIndividual[msg.sender] = true;
    votedHolders.add(1);
  }

  /**
   *  Voters in percents "voted / totalHolders"
   */
  function getRefundVotes() view public returns (uint) {
    return SafeMath.percentage(votedHolders, countAddresses());
  }

}
