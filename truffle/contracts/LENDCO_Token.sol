pragma solidity ^0.4.15;

contract ERC20Basic {
	uint256 public totalSupply;
	function balanceOf(address who) public constant returns (uint256);
	function transfer(address to, uint256 value) public returns (bool);
	event Transfer(address indexed from, address indexed to, uint256 value);
}
contract ERC20 is ERC20Basic {
	function allowance(address owner, address spender) public constant returns (uint256);
	function transferFrom(address from, address to, uint256 value) public returns (bool);
	function approve(address spender, uint256 value) public returns (bool);
	event Approval(address indexed owner, address indexed spender, uint256 value);
}
library SafeMath {
	function mul(uint256 a, uint256 b) internal constant returns (uint256) {
		uint256 c = a * b;
		assert(a == 0 || c / a == b);
		return c;
	}

	function div(uint256 a, uint256 b) internal constant returns (uint256) {
		uint256 c = a / b;
		return c;
	}

	function sub(uint256 a, uint256 b) internal constant returns (uint256) {
		assert(b <= a);
		return a - b;
	}

	function add(uint256 a, uint256 b) internal constant returns (uint256) {
		uint256 c = a + b;
		assert(c >= a);
		return c;
	}
}
contract BasicToken is ERC20Basic {
		
	using SafeMath for uint256;

	mapping(address => uint256) balances;

	function transfer(address _to, uint256 _value) public returns (bool) {
		balances[msg.sender] = balances[msg.sender].sub(_value);
		balances[_to] = balances[_to].add(_value);
		Transfer(msg.sender, _to, _value);
		return true;
	}

	function balanceOf(address _owner) public constant returns (uint256 balance) {
		return balances[_owner];
	}
}

contract StandardToken is ERC20, BasicToken {

	mapping (address => mapping (address => uint256)) allowed;

	function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
		var _allowance = allowed[_from][msg.sender];

		balances[_to] = balances[_to].add(_value);
		balances[_from] = balances[_from].sub(_value);
		allowed[_from][msg.sender] = _allowance.sub(_value);
		Transfer(_from, _to, _value);
		return true;
	}

	function approve(address _spender, uint256 _value) public returns (bool) {
		require((_value == 0) || (allowed[msg.sender][_spender] == 0));

		allowed[msg.sender][_spender] = _value;
		Approval(msg.sender, _spender, _value);
		return true;
	}

	function allowance(address _owner, address _spender) public constant returns (uint256 remaining) {
		return allowed[_owner][_spender];
	}

}

contract Ownable {
	address public owner;
	function Ownable() public { owner = msg.sender; }
	modifier onlyOwner() {
		require(msg.sender == owner);
		_;
	}
	function transferOwnership(address newOwner) public onlyOwner {
		require(newOwner != address(0));      
		owner = newOwner;
	}
}
contract MintableToken is StandardToken, Ownable {
		
	event Mint(address indexed to, uint256 amount);
	
	event MintFinished();

	bool public mintingFinished = false;

	modifier canMint() {
		require(!mintingFinished);
		_;
	}

	function mint(address _to, uint256 _amount) public onlyOwner canMint returns (bool) {
		totalSupply = totalSupply.add(_amount);
		balances[_to] = balances[_to].add(_amount);
		Mint(_to, _amount);
		return true;
	}

	function finishMinting() public onlyOwner returns (bool) {
		mintingFinished = true;
		MintFinished();
		return true;
	}
	
}

contract LENDCO_Token is MintableToken {
	// 150`000`000 tokens
	uint256 public totalSupply = 150000000000000000000000000; 
	
	string public constant name = "LENDCO";
	
	string public constant symbol = "LOAN";
	
	uint32 public constant decimals = 18;
		
}


contract MainSale is Ownable {
		
	using SafeMath for uint;
	
	address public multisig;

	uint public restrictedPercent;

	address public restricted;

	LENDCO_Token public token = new LENDCO_Token();

	uint public start;
	
	uint public period;

	uint public hardcap;

	uint public rate;
	
	uint public softcap;
	
	mapping(address => uint) public balances;

	function MainSale() public {
		// Адрес куда будет перечислятся эфир — multisig.
  		multisig = 0x2fc46fF16777d01e08514345589Ae98546FAB34d;
  		// Адрес куда будут перечисляться токены для наших нужд — restricted.
		restricted = 0x22A0f4407d7A08e3f2DCb5B4e3b7d94b65a1E225;
		// Процент токенов на наши нужды restrictedPercent пусть будет 40%.
		restrictedPercent = 40;
		// rate у нас будет — 100000000000000000000
		rate = 100000000000000000000; // 100 * 10^18
		// Время начала ICO  — GMT в UNIX формате — start. В UNIX — 1500379200.
		// now -- выдает время на момент публикации контракта
		start = now;

		period = 28;
		
		hardcap = 10000000000000000000000; // 10`000 * 10^18
		
		softcap = 1000000000000000000000; // 1`000 * 10^18
	}

	// модификатор проверяет активна ли сейчас распрдажа, 
	// если нет, останавливает выполнение кода
	modifier saleIsOn() {
		require(now > start && now < start + period * 1 days);
		_;
	}
	// модификатор проверяет собранна ли максимально необходимая сумма средств
	modifier isUnderHardCap() {
		require(multisig.balance <= hardcap);
		_;
	}
	// функция возвращает средства инвесторам при условии 
	// если закончился период сбора средств и сумма не набрала минимального капитала
	// данную фукцию вызывает инвестор
	function refund() public {
		require(this.balance < softcap && now > start + period * 1 days);
		uint value = balances[msg.sender]; 
		balances[msg.sender] = 0; 
		msg.sender.transfer(value); 
	}

	function finishMinting() public onlyOwner {
		if(this.balance > softcap) {
			multisig.transfer(this.balance);
			uint issuedTokenSupply = token.totalSupply();
			uint restrictedTokens = issuedTokenSupply.mul(restrictedPercent).div(100 - restrictedPercent);
			token.mint(restricted, restrictedTokens);
			token.finishMinting();
		}
	}

	function createTokens() public isUnderHardCap saleIsOn payable {
		uint tokens = rate.mul(msg.value).div(1 ether);
		uint bonusTokens = 0;

		// условия бонусной системы зависит от временных этапов

		if(now < start + (period * 1 days).div(4)) {
			bonusTokens = tokens.div(4);
		} else if(now >= start + (period * 1 days).div(4) && now < start + (period * 1 days).div(4).mul(2)) {
			bonusTokens = tokens.div(10);
		} else if(now >= start + (period * 1 days).div(4).mul(2) && now < start + (period * 1 days).div(4).mul(3)) {
			bonusTokens = tokens.div(20);
		}

		tokens += bonusTokens;
		token.mint(msg.sender, tokens);
		balances[msg.sender] = balances[msg.sender].add(msg.value);
	}

	function() external payable {
		createTokens();
	}		
}