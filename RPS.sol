// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./TimeUnit.sol";
import "./CommitReveal.sol";

contract RPS {
    uint public numPlayer = 0;
    uint public reward = 0;
    mapping(address => bytes32) public player_commit;
    mapping(address => uint) public player_choice;
    address[] public players;
    uint public numInput = 0;
    uint256 public gameStartTime;
    uint256 public gameTimeout = 6 minutes;

    TimeUnit public timeUnit;
    CommitReveal public commitReveal;

    // Constructor: กำหนดที่อยู่ของ contract TimeUnit และ CommitReveal
    constructor(address _timeUnitAddress, address _commitRevealAddress) {
        timeUnit = TimeUnit(_timeUnitAddress);
        commitReveal = CommitReveal(_commitRevealAddress);
    }

    // รายชื่อที่อยู่ของผู้เล่นที่ได้รับอนุญาตให้เล่นเกม
    address[4] private Players = [
        0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,
        0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
        0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db,
        0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
    ];

    // Modifier: ตรวจสอบว่าผู้ที่เรียกฟังก์ชันเป็นผู้เล่นที่ได้รับอนุญาตหรือไม่
    modifier onlyAllowedPlayers() {
        bool isAllowed = false;
        for (uint i = 0; i < Players.length; i++) {
            if (msg.sender == Players[i]) {
                isAllowed = true;
                break;
            }
        }
        require(isAllowed, "Not an allowed player");
        _;
    }

    // ฟังก์ชันให้ผู้เล่นเข้าร่วมเกม โดยต้องจ่าย 1 ETH
    function addPlayer() public payable onlyAllowedPlayers {
        require(numPlayer < 2, "Game is full");
        require(msg.value == 1 ether, "Must send exactly 1 ETH");
        require(players.length == 0 || msg.sender != players[0], "Player already joined");

        if (numPlayer == 0) {
            gameStartTime = block.timestamp;
        }

        reward += msg.value;
        players.push(msg.sender);
        numPlayer++;
    }

    // ฟังก์ชันให้ผู้เล่น Commit ตัวเลือกโดยส่งค่า Hash
    function commitChoice(bytes32 dataHash) public onlyAllowedPlayers {
        require(numPlayer == 2, "Game not started");
        require(player_commit[msg.sender] == 0, "Already committed");
        commitReveal.commit(dataHash);
        player_commit[msg.sender] = dataHash;
    }

    // ฟังก์ชันให้ผู้เล่น Reveal ตัวเลือก โดยต้องส่งค่า choice และ nonce ที่ตรงกับ Hash ที่ Commit ไปก่อนหน้านี้
    function revealChoice(uint choice, uint nonce) public onlyAllowedPlayers {
        require(numPlayer == 2, "Game not started");
        require(player_commit[msg.sender] != 0, "You have not committed");
        require(choice >= 0 && choice <= 4, "Invalid choice");
        require(commitReveal.getHash(keccak256(abi.encodePacked(choice, nonce))) == player_commit[msg.sender], "Invalid reveal");

        player_choice[msg.sender] = choice;
        numInput++;

        if (numInput == 2) {
            _checkWinnerAndPay();
        }
    }

    // ฟังก์ชันคืนเงินกรณีที่ไม่มีการ Reveal ภายในเวลาที่กำหนด
    function withdrawIfTimeout() public {
        require(block.timestamp >= gameStartTime + gameTimeout, "Game not timed out yet");
        
        if (numPlayer == 1) {
            payable(players[0]).transfer(reward);
        } else if (numPlayer == 2) {
            payable(players[0]).transfer(reward / 2);
            payable(players[1]).transfer(reward / 2);
        }
        _resetGame();
    }

    // ฟังก์ชันตรวจสอบผลการแข่งขัน และโอนรางวัลให้ผู้ชนะ
    function _checkWinnerAndPay() private {
        uint p0Choice = player_choice[players[0]];
        uint p1Choice = player_choice[players[1]];
        address payable account0 = payable(players[0]);
        address payable account1 = payable(players[1]);

        if ((p0Choice + 1) % 5 == p1Choice || (p0Choice + 3) % 5 == p1Choice) {
            account1.transfer(reward);
        } else if ((p1Choice + 1) % 5 == p0Choice || (p1Choice + 3) % 5 == p0Choice) {
            account0.transfer(reward);
        } else {
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
        }
        _resetGame();
    }

    // ฟังก์ชันรีเซ็ตค่าทุกอย่างเพื่อเริ่มเกมใหม่
    function _resetGame() private {
        reward = 0;
        numPlayer = 0;
        numInput = 0;
        delete player_commit[players[0]];
        delete player_commit[players[1]];
        delete player_choice[players[0]];
        delete player_choice[players[1]];
        players = new address[](0);
        gameStartTime = 0;
    }

    // ฟังก์ชันใช้สำหรับคำนวณ Hash ที่ผู้เล่นต้อง Commit ก่อนเล่นเกม
    function getHash(uint choice, uint nonce) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(choice, nonce));
    }
}