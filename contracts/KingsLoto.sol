pragma solidity 0.4.22;

import "./zeppelin-solidity/contracts/math/SafeMath.sol";


/**
* @dev Ottolotto DAO
*/
contract iOttolottoDao {
    /**
    * @dev Compare address with company rule executor.
    */
    function onlyCompany(address) public view returns (bool) {}
}


/**
* @dev Ottolotto platform referral system interface.
*/
contract iReferralSystem {
    /**
    * @dev Create new referral
    */
    function addReferral(address, address) public returns (bool) {}

    /**
    * @dev Get percent by referral system.
    */
    function getPercent(address) public view returns (uint8) {}

    /**
    * @dev Get partner in referral system by referral address.
    */
    function getPartner(address) public view returns (address) {}
}


/**
* @title KingsLoto game
*
* In fact, it’s the most transparent and fair lottery in the world!
* Player buys a ticket with cryptocurrency and chooses his 6 lucky numbers (from 0 to 15). 
* Twice a week (Tuesday and Friday) lottery should start from the block hash, 
* which was set in advance in the draw info. We’ll take the last number of each hash 
* (this is exactly that ball, which is used in the regular lottery). 
* Six hashes - six lucky numbers in the end. Then smart-contract is processing the draw 
* information and sends all prizes automatically to the winners' wallets!
* One ticket plays twice - in regular lottery draw and in the Grand Jackpot draw on the 21st of December.
* This means somebody will receive all money for sure!
*/
contract KingsLoto {
    using SafeMath for uint256;
    using SafeMath for uint8;

    /**
    * @dev Write info to log when the game was started.
    *
    * @param _game Started game.
    * @param _nextGame Next game number.
    */
    event StartedGame(uint256 indexed _game, uint256 _nextGame);

    /**
    * @dev Write to log info about bets calculation progress.
    *
    * @param _game Processed game.
    * @param _processed A number of processed bets.
    * @param _toProcess Total of bets.
    */
    event GameProgress(uint256 indexed _game, uint256 _processed, uint256 _toProcess);
    
    /**
    * @dev Write to log info about ticket selling.
    *
    * @param _game The game number on which ticket was sold.
    * @param _address Buyer address.
    * @param bet Player bet.
    */
    event Ticket(uint256 indexed _game, address indexed _address, bytes3 bet);

    /**
    * @dev Write info to log about winner when calculating stats.
    * 
    * @param _address Winner address.
    * @param _game A number of the game.
    * @param _matches A number of matches.
    * @param _bet Winning Bet.
    * @param _time Time of determining the winner.
    */
    event Winning(
        address indexed _address,
        uint256 indexed _game,
        uint8 _matches,
        bytes3 _bet,
        uint256 _time
    );
    
    /**
    * @dev Write info to log when the bet was paid.
    *
    * @param _address Address of the winner (recipient).
    * @param _game A number of the game.
    * @param _matches A number of matches.
    * @param _bet Winning Bet.
    * @param _amount Prize amount (in wei).
    * @param _time A time when the bet was paid.
    */
    event BetPaid(
        address indexed _address,
        uint256 indexed _game,
        uint8 _matches,
        bytes3 _bet,
        uint256 _amount,
        uint256 _time
    );
    
    /**
    * @dev Write info to log about jackpot winner.
    *
    * @param _address Address of the winner (recipient).
    * @param _game A number of the game.
    * @param _amount Prize amount (in wei).
    * @param _time Time of determining the jackpot winner.
    */
    event Jackpot(
        address indexed _address,
        uint256 indexed _game,
        uint256 _amount,
        uint256 _time
    );
    
    /**
    * @dev Write to log info about raised funds in referral system.
    *
    * @param _partner Address of the partner which get funds.
    * @param _referral Referral address.
    * @param _type Referral payment type (0x00 - ticket selling, 0x01 winnings in the game).
    * @param _game A number of the game.
    * @param _amount Raised funds amount by the partner.
    * @param _time A time when funds were sent to partner.
    */
    event RaisedByPartner(
        address indexed _partner,
        address indexed _referral,
        bytes1 _type,
        uint256 _game,
        uint256 _amount,
        uint256 _time
    );
    
    /**
    * @dev Write info to log about grand jackpot game starting.
    *
    * @param _game A number of the game.
    * @param _time A time when the game was started.
    */
    event ChampionGameStarted(uint256 indexed _game, uint256 _time);
    
    /**
    * @dev Write info to log about the new player in the grand jackpot.
    *
    * @param _player Player address.
    * @param _game A number of the grand jackpot game.
    * @param _number Player number in the game.
    */
    event ChampionPlayer(address indexed _player, uint256 indexed _game, uint256 _number);
    
    /**
    * @dev Write info to log about the winner in the grand jackpot.
    * 
    * @param _winner Address of the winner.
    * @param _game A number of the game.
    * @param _number Player number in the game.
    * @param _jackpot Prize.
    * @param _time A time when the prize was sent to the winner.
    */
    event ChampionWinner(
        address indexed _winner,
        uint256 indexed _game,
        uint256 _number,
        uint256 _jackpot,
        uint256 indexed _time
    );

    /**
    * @dev Bet struct
    * contain info about the player bet.
    */
    struct Bet {
        address player;
        bytes3  bet;
    }

    /**
    * @dev Winner struct
    * contain info about the winner.
    */
    struct Winner {
        uint256 betIndex;
        uint8 matches;
    }

    /**
    * @dev Declares a state variable that stores game winners.
    */
    mapping(uint256 => Winner[]) winners;

    /**
    * @dev Declares a state variable that stores game bets.
    */
    mapping(uint256 => Bet[]) gameBets;
   
    /**
    * @dev Declares a state variable that stores game jackpots.
    */
    mapping(uint256 => uint256) weiRaised;

    /**
    * @dev Declares a state variable that stores game start block.
    */
    mapping(uint256 => uint256) gameStartBlock;

    /**
    * @dev Declares a state variable that stores calculated game stats.
    */
    mapping(uint256 => uint32[7]) gameStats;

    /**
    * @dev Declares a state variable that stores game miscalculation status.
    */
    mapping(uint256 => bool) gameCalculated;

    /**
    * @dev Declares a state variable that stores game calculation progress status.
    */
    mapping(uint256 => uint256) gameCalculationProgress;

    /**
    * @dev Declares a state variable that stores bet payments progress.
    */
    mapping(uint256 => uint256) betsPaymentsProgress;

    /**
    * @dev Declares a state variable that stores percentages for funds distribution.
    */
    mapping(uint8 => uint8) percents;

    /**
    * @dev Declares a state variable that stores a last byte of the game blocks.
    */
    mapping(uint256 => bytes1[6]) gameBlocks;

    /**
    * @dev Declares a state variable that stores a game jackpot,
    * if the jackpot is raised in this game.
    */
    mapping(uint256 => uint256) raisedJackpots;

    /**
    * @dev First game interval in seconds.
    */
    uint256 constant GAME_INTERVAL_ONE = 259200;
    
    /**
    * @dev Second game interval in seconds.
    */
    uint256 constant GAME_INTERVAL_TWO = 345600;

    /**
    * @dev Last game start time.
    */
    uint256 public gameStartedAt = 1524830400;

    /**
    * @dev Marks current lotto interval.
    */
    bool public isFristInterval = false;
    
    /**
    * @dev Variable that store jackpot value.
    */
    uint256 public jackpot;
    
    /**
    * @dev Next game number.
    */
    uint256 public gameNext;

    /**
    * @dev Played game number.
    */
    uint256 public gamePlayed;

    /**
    * @dev Lotto game duration in blocks.
    */  
    uint8   public gameDuration = 6;

    /**
    * @dev The interval which will be added to the start block number.
    */
    uint8   public startBlockInterval = 12;

    /**
    * @dev Status of the played game (true if the game is in the process, false if the game is finished).
    */
    bool public gamePlayedStatus = false;
    
    /**
    * @dev Ticket price.
    */
    uint256 public ticketPrice = 0.001 ether;
    
    /**
    * @dev New ticket price for the next game.
    */
    uint256 public newPrice = 0;
    
    // Stats of the Grand jackpot.
    
    /**
    * @dev Define constant which indicates rules.
    */
    uint8 constant NUMBER = 1;
    
    /**
    * @dev Define constant which indicates rules.
    */
    uint8 constant STRING = 0;

    /**
    * @dev Steps for calculation leap year.
    */
    uint8 public leapYearStep = 2;

    /**
    * @dev Interval of the Grand jackpot game in the standard year.
    */
    uint256 constant CHAMPION_GAME_INTERVAL_ONE = 31536000;
    
    /**
    * @dev Interval of the Grand jackpot game in the leap year.
    */
    uint256 constant CHAMPION_GAME_INTERVAL_TWO = 31622400;

    /**
    * @dev Last start time for the Grand jackpot.
    */
    uint256 public championGameStartedAt = 1482321600;

    /**
    * @dev A number of the next Grand jackpot game.
    */
    uint256 public game = 0;
    
    /**
    * @dev A number of the current Grand jackpot game.
    */
    uint256 public currentGameBlockNumber;
    
    /**
    * @dev Declares a state variable that stores game start block.
    */
    mapping(uint256 => uint256) internal championGameStartBlock;

    /**
    * @dev Declares a state variable that stores game start block.
    */
    mapping(uint256 => address[]) internal gamePlayers;

    /**
    * @dev Commission of the platform in this game.
    */
    uint256 commission = 21;

    /**
    * @dev Ottolotto DAO instance.
    */
    iOttolottoDao public dao;

    /**
    * @dev Ottolotto referral system instance. 
    */
    iReferralSystem public referralSystem;

    /**
    * @dev Initialize smart contract.
    */
    constructor() public {
        gameNext = block.number;
        game = block.number;
        
        percents[1] = 5;
        percents[2] = 8;
        percents[3] = 12;
        percents[4] = 15;
        percents[5] = 25;
        percents[6] = 35;

        dao = iOttolottoDao(0x24643A6432721070943a389f0D6445FC3F57e18C);
        referralSystem = iReferralSystem(0x0BD15B6A36f6002AEe906ECdf73877387E66AF96);
    }

    /**
    * @dev Get game prize
    *
    * @param _game A number of the game.
    */
    function getGamePrize(uint256 _game)
        public 
        view 
        returns (uint256)
    {
        return weiRaised[_game];            
    }
    
    /**
    * @dev Get game start block
    *
    * @param _game A number of the game.
    */
    function getGameStartBlock(uint256 _game) 
        public 
        view 
        returns (uint256)
    {
        return gameStartBlock[_game];
    }
    
    /**
    * @dev Get game calculation progress.
    *
    * @param _game A number of the game.
    */
    function getGameCalculationProgress(uint256 _game) 
        public 
        view 
        returns (uint256)
    {
        return gameCalculationProgress[_game];
    }

    /**
    * @dev Get players counts in the game.
    *
    * @param _game A number of the game.
    */
    function getPlayersCount(uint256 _game)
        public 
        view 
        returns (uint256)
    {
        return gameBets[_game].length;
    }

    /**
    * @dev Get game calculated stats.
    *
    * @param _game A number of the game.
    */
    function getGameCalculatedStats(uint256 _game)
        public 
        view 
        returns (uint32[7])
    {
        return gameStats[_game];
    }

    /**
    * @dev Get stored game blocks in the contract.
    *
    * @param _game A number of the game.
    */
    function getStoredGameBlocks(uint256 _game) 
        public 
        view 
        returns (bytes1[6])
    {
        return gameBlocks[_game];
    }

    /**
    * @dev Get bets payment progress.
    *
    * @param _game A number of the game.
    */
    function getBetsPaymentsProgress(uint256 _game) 
        public 
        view 
        returns (uint256)
    {
        return betsPaymentsProgress[_game];
    }

    /**
    * @dev Check if bets are paid in the game.
    *
    * @param _game A number of the game.
    */
    function betsArePayed(uint256 _game) public view returns (bool) {
        return betsPaymentsProgress[_game] == winners[_game].length;
    }

    /**
    * @dev Get current game interval.
    */
    function getCurrentInterval() public view returns (uint256) {
        if (isFristInterval) {
            return GAME_INTERVAL_ONE;
        }

        return GAME_INTERVAL_TWO;
    }

    /**
    * @dev Get game target date.
    */
    function targetDate() public view returns (uint256) {
        return gameStartedAt + getCurrentInterval();
    }

    /**
    * @dev Change game interval.
    */
    function toogleInterval() internal {
        uint256 interval = getCurrentInterval();
        gameStartedAt += interval;

        isFristInterval = !isFristInterval;
    }

    /**
    * @dev Make bet function.
    *
    * @param _bet Player bet.
    * @param _partner Referral system partner address.
    */
    function makeBet(bytes3 _bet, address _partner) public payable {
        require(msg.value == ticketPrice);

        gameBets[gameNext].push(Bet({player: msg.sender, bet: _bet}));
        
        uint256 reised = ticketPrice;

        address partner = referralSystem.getPartner(msg.sender);
        if (_partner != 0x0 || partner != 0x0) {
            if (partner == 0x0) {
                referralSystem.addReferral(msg.sender, _partner);
                partner = _partner;
            }
            uint8 percent = referralSystem.getPercent(partner);

            uint256 toPartner = reised.mul(percent).div(100);
            partner.transfer(toPartner);
            emit RaisedByPartner(
                partner,
                msg.sender,
                0x00,
                gameNext,
                toPartner,
                now
            );
            reised -= toPartner;
        }

        weiRaised[gameNext] += reised;
        
        emit Ticket(gameNext, msg.sender, _bet);

        buyChampionTicket(msg.sender);
    }

    /**
    * @dev Add a player to the Grand jackpot game.
    *
    * @param _player Player address.
    */
    function buyChampionTicket(address _player) internal {
        gamePlayers[game].push(_player);

        emit ChampionPlayer(
            _player,
            currentGameBlockNumber,
            gamePlayers[game].length
        );
    }

    /**
    * @dev Starting lotto game.
    */
    function startGame() public {
        require(targetDate() <= now);

        gamePlayed = gameNext;
        gameNext = block.number;
        gamePlayedStatus = true;

        gameStartBlock[gamePlayed] = block.number + startBlockInterval;

        if (weiRaised[gamePlayed] != 0) {
            jackpot += weiRaised[gamePlayed].mul(percents[6]).div(100);
        }
        
        toogleInterval();

        emit StartedGame(gamePlayed, gameNext);

        if (newPrice != 0) {
            ticketPrice = newPrice;
            newPrice = 0;
        }
    }

    /**
    * @dev Bitwise shifts for bet comparison.
    *
    * @param _bet Player bet.
    * @param _step Step.
    */
    function bitwiseShifts(bytes3 _bet, uint8 _step) 
        internal 
        pure 
        returns (bytes3)
    {
        return _bet >> (20 - (_step * 4)) << 20 >> 4;
    }

    /**
    * @dev Get matches in the bet.
    *
    * @param _game A number of the game.
    * @param _bet Bet.
    */
    function getMatches(uint256 _game, bytes3 _bet) 
        public 
        view 
        returns (uint8)
    {
        uint8 matches = 0;
        for (uint8 i = 0; i < gameDuration; i++) {
            if (gameBlocks[_game][i] ^ bitwiseShifts(_bet, i) == 0) {
                matches++;
                continue;
            }
            break;
        }
        
        return matches;
    }

    /**
    * @dev Get matches in the game.
    *
    * @param _game A number of the game.
    */    
    function getAllMatches(uint256 _game) 
        public 
        view 
        returns (uint256[])
    {
        uint256[] memory matches = new uint256[](7);
        for (uint32 i = 0; i < gameBets[_game].length; i++) {
            uint8 matched = getMatches(_game, gameBets[_game][i].bet);
            if (matched == 0) {
                continue;
            }
            matches[matched] += 1;
        }
        
        return matches;
    }

    /**
    * @dev Check if the game is over.
    *
    * @param _game A number of the game.
    */
    function gameIsOver(uint256 _game) 
        public 
        view 
        returns (bool)
    {
        if (gameStartBlock[_game] == 0) {
            return false;
        }

        return (gameStartBlock[_game] + gameDuration - 1) < block.number;   
    }

    /**
    * @dev Check if the game is calculated.
    *
    * @param _game A number of the game.
    */
    function gameIsCalculated(uint256 _game) public view returns (bool) {
        return gameCalculated[_game];
    }

    /**
    * @dev Update game to calculated.
    *
    * @param _game A number of the game.
    */
    function updateGameToCalculated(uint256 _game) internal {
        gameCalculated[_game] = true;
        gamePlayedStatus = false;
    }

    /**
    * @dev Init game blocks.
    *
    * @param _game A number of the game.
    * @param _startBlock A number of the start block.
    */
    function initGameBlocks(uint256 _game,uint256 _startBlock) internal {
        for (uint8 i = 0; i < gameDuration; i++) {
            bytes32 blockHash = blockhash(_startBlock + i);
            gameBlocks[_game][i] = blockHash[31] << 4 >> 4;
        }
    }

    /**
    * @dev Process game.
    *
    * @param _game A number of the game.
    * @param _calculationStep Calculation step.
    */
    function processGame(uint256 _game, uint256 _calculationStep) 
        public 
        returns (bool)
    {
        require(gameIsOver(_game));

        if (gameIsCalculated(_game)) {
            return true;
        }


        if (gameCalculationProgress[_game] == gameBets[_game].length) {
            updateGameToCalculated(_game);
            return true;
        }

        uint256 steps = _calculationStep;
        if (gameCalculationProgress[_game] + steps > gameBets[_game].length) {
            steps -= gameCalculationProgress[_game] + steps - gameBets[_game].length;
        }
    
        uint32[] memory matches = new uint32[](7);
        uint256 to = gameCalculationProgress[_game] + steps;
        uint256 startBlock = getGameStartBlock(_game);
        if (gameBlocks[_game][0] == 0x0) {
            initGameBlocks(_game, startBlock);
        }

        uint256 i = gameCalculationProgress[_game];
        for (; i < to; i++) {
            uint8 matched = getMatches(_game, gameBets[_game][i].bet);
            if (matched == 0) {
                continue;
            }
            matches[matched] += 1;
            winners[_game].push(
                Winner({
                    betIndex: i,
                    matches: matched
                })
            );

            emit Winning(
                gameBets[_game][i].player,
                _game,
                matched,
                gameBets[_game][i].bet,
                now
            );
        }

        gameCalculationProgress[_game] += steps;

        for (i = 1; i <= 6; i++) {
            gameStats[_game][i] += matches[i];
        }

        emit GameProgress(_game, gameCalculationProgress[_game], gameBets[_game].length);
        if (gameCalculationProgress[_game] == gameBets[_game].length) {
            updateGameToCalculated(_game);
            distributeRaisedWeiToJackpot(_game);
            return true;
        }

        return false;
    }

    /**
    * @dev Distribute raised Wei to Jackpot if there are no matches.
    *
    * @param _game A number of the game.
    */ 
    function distributeRaisedWeiToJackpot(uint256 _game) internal {
        for (uint8 i = 1; i <= 5; i ++) {
            if (gameStats[_game][i] == 0) {
                jackpot += weiRaised[_game].mul(percents[i]).div(100);
            }
        }
    }

    /**
    * @dev Change ticket price on the next game.
    *
    * @param _newPrice New ticket price.
    */
    function changeTicketPrice(uint256 _newPrice) public {
        require(dao.onlyCompany(msg.sender));
        
        newPrice = _newPrice;
    }

    /**
    * @dev Distribute funds to the winner, platform, and partners.
    *
    * @param _weiWin Funds for distribution.
    * @param _game A number of the game.
    * @param _matched A number of the player matches.
    * @param _player Player address.
    * @param _bet Player bet.
    */
    function distributeFunds(
        uint256 _weiWin,
        uint256 _game,
        uint8 _matched,
        address _player,
        bytes3 _bet
    ) 
        internal 
    {
        uint256 toOwner = _weiWin.mul(commission).div(100);
        uint256 toPartner = 0;

        address partner = referralSystem.getPartner(msg.sender);
        if (partner != 0x0) {
            toPartner = toOwner.div(100);
            partner.transfer(toPartner);
            emit RaisedByPartner(
                partner,
                _player,
                0x01,
                _game,
                toPartner,
                now
            );
        }

        _player.transfer(_weiWin - toOwner);
        bool result = address(dao)
                        .call
                        .gas(20000)
                        .value(toOwner - toPartner)(bytes4(keccak256("acceptFunds()")));

        if (!result) {
            revert();
        }

        emit BetPaid(
            _player,
            _game,
            _matched,
            _bet,
            _weiWin,
            now
        );
        if (_matched == 6) {
            emit Jackpot(
                _player,
                _game,
                _weiWin,
                now
            );
        }
    }

    /**
    * @dev Make payments in calculated game.
    *
    * @param _game A number of the game.
    * @param _toProcess Amount of payments for the process.
    */
    function makePayments(uint256 _game, uint256 _toProcess) public {
        require(gameIsCalculated(_game));
        require(winners[_game].length != 0);
        require(betsPaymentsProgress[_game] < winners[_game].length);

        uint256 steps = _toProcess;
        if (betsPaymentsProgress[_game] + steps > winners[_game].length) {
            steps -= betsPaymentsProgress[_game] + steps - winners[_game].length;
        }

        uint256 weiWin = 0;
        uint256 to = betsPaymentsProgress[_game] + steps;
        for (uint256 i = betsPaymentsProgress[_game]; i < to; i++) {
            if (winners[_game][i].matches != 6) {
                uint256 weiByMatch = weiRaised[gamePlayed].mul(percents[winners[_game][i].matches]).div(100);
                weiWin = weiByMatch.div(gameStats[_game][winners[_game][i].matches]);
            } else {
                if (raisedJackpots[_game] == 0 && jackpot != 0) {
                    raisedJackpots[_game] = jackpot;
                    jackpot = 0;
                }
                weiWin = raisedJackpots[_game].div(gameStats[_game][winners[_game][i].matches]);
            }
            
            distributeFunds(
                weiWin,
                _game,
                winners[_game][i].matches,
                gameBets[game][winners[_game][i].betIndex].player,
                gameBets[game][winners[_game][i].betIndex].bet
            );
        }
        betsPaymentsProgress[_game] = i;
    }

    /**
    * @dev Get Grand jackpot start block.
    *
    * @param _game A number of the game.
    */
    function getChampionStartBlock(uint256 _game) 
        public 
        view 
        returns (uint256) 
    {
        return championGameStartBlock[_game];
    }

    /**
    * @dev Get players in Grand jackpot.
    *
    * @param _game A number of the game.
    */
    function getChampionPlayersCountByGame(uint256 _game) 
        public 
        view 
        returns (uint256)
    {
        return gamePlayers[_game].length;
    }

    /**
    * @dev Check if is number at the end of the game hash.
    *
    * @param _game A number of the game.
    */
    function isNumber(uint256 _game) private view returns (bool) {
        bytes32 hash = blockhash(_game);
        require(hash != 0x0);
        
        byte b = byte(hash[31]);
        uint hi = uint8(b) / 16;
        uint lo = uint8(b) - 16 * uint8(hi);
        
        if (lo <= 9) {
            return true;
        }
        
        return false;
    }

    /**
    * @dev Get Grand jackpot interval.
    */
    function getChampionCurrentInterval() 
        public 
        view 
        returns (uint256)
    {
        if (leapYearStep != 4) {
            return CHAMPION_GAME_INTERVAL_ONE;
        }

        return CHAMPION_GAME_INTERVAL_TWO;
    }

    /**
    * @dev Get target Grand jackpot date.
    */
    function targetChampionDate() 
        public 
        view 
        returns (uint256)
    {
        return championGameStartedAt + getChampionCurrentInterval();
    }

    /**
    * @dev Change step.
    */
    function changeChampionStep() internal {
        uint256 interval = getChampionCurrentInterval();
        championGameStartedAt += interval;

        if (leapYearStep == 4) {
            leapYearStep = 1;
        } else {
            leapYearStep += 1;
        }
    }

    /**
    * @dev Starts Grand jackpot game.
    */
    function startChampionGame() public {
        require(currentGameBlockNumber == 0);
        require(targetChampionDate() <= now);

        currentGameBlockNumber = game;
        game = block.number;
        championGameStartBlock[currentGameBlockNumber] = block.number + startBlockInterval;

        emit ChampionGameStarted(currentGameBlockNumber, now);
        changeChampionStep();
    }

    /**
    * @dev Finish Grand jackpot game.
    */
    function finishChampionGame() public {
        require(currentGameBlockNumber != 0);
        
        uint8 steps = getCurrentGameSteps();
        uint256 startBlock = getChampionStartBlock(currentGameBlockNumber);
        require(startBlock + steps < block.number);

        if (gamePlayers[currentGameBlockNumber].length != 0) {            
            uint256 lMin = 0;
            uint256 lMax = 0;
            uint256 rMin = 0;
            uint256 rMax = 0;
            
            (lMin, lMax, rMin, rMax) = processSteps(currentGameBlockNumber, steps);
            
            address winner = gamePlayers[currentGameBlockNumber][rMax];

            uint256 toOwner = jackpot.mul(commission).div(100);
            uint256 jp = jackpot - toOwner;
            emit ChampionWinner(
                winner,
                currentGameBlockNumber,
                rMax,
                jackpot,
                now
            );

            winner.transfer(jp);

            uint256 toPartner = 0;
            address partner = referralSystem.getPartner(winner);
            if (partner != 0x0) {
                toPartner = toOwner.mul(1).div(100);
                partner.transfer(toPartner);
                emit RaisedByPartner(
                    partner,
                    winner,
                    0x01,
                    currentGameBlockNumber,
                    toPartner,
                    now
                );
            }

            bool result = address(dao)
                        .call
                        .gas(20000)
                        .value(toOwner - toPartner)(bytes4(keccak256("acceptFunds()")));
                        
            if (!result) {
                revert();
            }

            jackpot = 0;
        }

        currentGameBlockNumber = 0;
    }
    
    /**
    * @dev Get steps in this Grand jackpot game.
    */
    function getCurrentGameSteps() 
        public 
        view 
        returns (uint8)
    {
        return uint8(getStepsCount(currentGameBlockNumber));
    }

    /**
    * @dev Calculate game steps.
    *
    * @param _game A number of the game.
    */
    function getStepsCount(uint256 _game) 
        public 
        view 
        returns (uint256 y)
    {
        uint256 x = getChampionPlayersCountByGame(_game);
        assembly {
            let arg := x
            x := sub(x,1)
            x := or(x, div(x, 0x02))
            x := or(x, div(x, 0x04))
            x := or(x, div(x, 0x10))
            x := or(x, div(x, 0x100))
            x := or(x, div(x, 0x10000))
            x := or(x, div(x, 0x100000000))
            x := or(x, div(x, 0x10000000000000000))
            x := or(x, div(x, 0x100000000000000000000000000000000))
            x := add(x, 1)
            let m := mload(0x40)
            mstore(m,           0xf8f9cbfae6cc78fbefe7cdc3a1793dfcf4f0e8bbd8cec470b6a28a7a5a3e1efd)
            mstore(add(m,0x20), 0xf5ecf1b3e9debc68e1d9cfabc5997135bfb7a7a3938b7b606b5b4b3f2f1f0ffe)
            mstore(add(m,0x40), 0xf6e4ed9ff2d6b458eadcdf97bd91692de2d4da8fd2d0ac50c6ae9a8272523616)
            mstore(add(m,0x60), 0xc8c0b887b0a8a4489c948c7f847c6125746c645c544c444038302820181008ff)
            mstore(add(m,0x80), 0xf7cae577eec2a03cf3bad76fb589591debb2dd67e0aa9834bea6925f6a4a2e0e)
            mstore(add(m,0xa0), 0xe39ed557db96902cd38ed14fad815115c786af479b7e83247363534337271707)
            mstore(add(m,0xc0), 0xc976c13bb96e881cb166a933a55e490d9d56952b8d4e801485467d2362422606)
            mstore(add(m,0xe0), 0x753a6d1b65325d0c552a4d1345224105391a310b29122104190a110309020100)
            mstore(0x40, add(m, 0x100))
            let value := 0x818283848586878898a8b8c8d8e8f929395969799a9b9d9e9faaeb6bedeeff
            let shift := 0x100000000000000000000000000000000000000000000000000000000000000
            let a := div(mul(x, value), shift)
            y := div(mload(add(m,sub(255,a))), shift)
            y := add(y, mul(256, gt(arg, 0x8000000000000000000000000000000000000000000000000000000000000000)))
        }
    }
     
    /**
    * @dev Refill the Jackpot.
    */
    function refillTheJackpot() public payable {
        require(msg.value > 0);
        jackpot += msg.value;
    }

    /**
    * @dev Get Grand jackpot game rules.
    *
    * @param _game A number of the game.
    */
    function getChampionGameRules(uint256 _game) 
        public 
        view 
        returns (uint8 left, uint8 right)
    {
        if (isNumber(_game)) {
            left = NUMBER;
            right = STRING;
        } else {
            left = STRING;
            right = NUMBER;
        }

        return (left, right);
    }

    /**
    * @dev Process Grand jackpot steps.
    *
    * @param _gameBlock A number of the game.
    * @param _step Step to which needed calculation. 
    */
    function processSteps(uint256 _gameBlock, uint8 _step) 
        public 
        view 
        returns (
            uint256 lMin, 
            uint256 lMax, 
            uint256 rMin, 
            uint256 rMax
        )
    {
        require(_gameBlock != 0);
        
        lMin = 0;
        lMax = 0;
        rMin = 0;
        rMax = gamePlayers[_gameBlock].length - 1;
        
        if (rMax == 0) {
            return (lMin, lMax, rMin, rMax);
        }

        if (gamePlayers[_gameBlock].length == 2) {
            rMin = rMax;
        } else if (isEvenNumber(rMax)) {
            lMax = rMax / 2;
            rMin = rMax / 2 + 1;
        } else {
            lMax = rMax / 2;
            rMin = rMax / 2 + 1;
        }
        
        if (_step == 0) {
            return (lMin, lMax, rMin, rMax);
        }

        uint256 startBlock = getChampionStartBlock(_gameBlock);
        require((startBlock + _step) < block.number);
        
        uint8 left = 0;
        uint8 right = 0;
        (left, right) = getChampionGameRules(startBlock);

        for (uint8 i = 1; i <= 35; i++) {
            if (lMin == lMax && lMin == rMin && lMin == rMax) {
                break;
            }

            bool isNumberRes = isNumber(startBlock + i);
            
            if ((isNumberRes && left == NUMBER) ||
                (!isNumberRes && left == STRING)
            ) {
                if (lMin == lMax) {
                    rMin = lMin;
                    rMax = lMax;
                    break;
                }
                
                rMax = lMax;
            } else if (isNumberRes && right == NUMBER ||
                (!isNumberRes && right == STRING)
            ) {
                if (rMin == rMax) {
                    lMin = rMin;
                    lMax = rMax;
                    break;
                }
                
                lMin = rMin;
            }
            
            if (rMax - lMin != 1) {
                lMax = lMin + (rMax - lMin) / 2;
                rMin = lMin + (rMax - lMin) / 2 + 1;
            } else {
                lMax = lMin;
                rMin = rMax;
            }

            if (i == _step) {
                break;
            }
        }
        
        return (lMin, lMax, rMin, rMax);
    }

    /**
    * @dev Check if is even number.
    *
    * @param _v1 Number.
    */
    function isEvenNumber(uint _v1) 
        internal 
        pure 
        returns (bool)
    {
        uint v1u = _v1 * 100;
        uint v2 = 2;
        
        uint vuResult = v1u / v2;
        uint vResult = _v1 / v2;
        
        if (vuResult != vResult * 100) {
            return false;
        }
        
        return true;
    }
}