// Interface contract
contract Token {
    function transfer(address to, uint amount) returns (bool);
    function transferFrom(address from, address to, uint amount) returns (bool);
    // Allows `by` to transfer `amount` of caller's tokens (to itself or anywhere else).
    function allowTransfer(address by, uint amount);
}
contract TokenImpl is Token {
    mapping(address => uint) public balances;
    struct allowance {
        address from;
        address to;
        uint amount;
    }
    mapping(address => mapping(address => uint)) public allowances;
    function allowTransfer(address by, uint amount) {
        allowances[msg.sender][by] = amount;
    }
    function transfer(address to, uint amount) returns (bool) {
        return doTransfer(msg.sender, to, amount);
    }
    function transferFrom(address from, address to, uint amount) returns (bool) {
        if (amount > allowances[from][msg.sender])
            return false;
        if (doTransfer(from, to, amount))
        {
            allowances[from][msg.sender] -= amount;
            return true;
        }
    }
    function doTransfer(address from, address to, uint amount) internal returns (bool) {
        if (balances[from] < amount) return false;
        balances[to] += amount;
        balances[from] -= amount;
        return true;
    }
}
contract Diamond is TokenImpl {
    function Diamond() { balances[msg.sender] = 10000; }
}
contract Beer is TokenImpl {
    function Beer() { balances[msg.sender] = 10000; }
}
// Simple decentralized exchange that does not allow splitting offers.
contract Exchange {
    struct offer {
        address seller;
        Token sell;
        Token buy;
        uint sellAmount;
        uint buyAmount;
    }
    offer[] public offers;
    function numOffers() constant returns (uint) {
        return offers.length;
    }
    
    function placeOffer(Token sell, Token buy, uint sellAmount, uint buyAmount) returns (uint) {
        if (!sell.transferFrom(msg.sender, this, sellAmount))
            throw;
        offers.push(offer({
            seller: msg.sender,
            sell: sell,
            buy: buy,
            sellAmount: sellAmount,
            buyAmount: buyAmount
        }));
        return offers.length - 1; // offer id
    }
    function deleteOffer(uint id) {
        if (msg.sender == offers[id].seller)
        {
            offers[id].sell.transfer(msg.sender, offers[id].sellAmount);
            delete offers[id]; // will not rearrange array, just set everything to 0
        }
    }
    function acceptOffer(uint id) {
        offer memory o = offers[id];
        if (o.seller == 0)
            throw;
        delete offers[id];
        if (!o.buy.transferFrom(msg.sender, o.seller, o.buyAmount))
            throw;
        if (!o.sell.transfer(msg.sender, o.sellAmount))
            throw;
    }
}

