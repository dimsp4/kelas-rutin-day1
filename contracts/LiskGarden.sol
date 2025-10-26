// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract LiskGarden {
    enum GrowthStage { SEED, SPROUT, GROWING, BLOOMING }

    struct Plant {
        uint8 id;
        address owner;
        GrowthStage stage;
        uint256 plantedDate;
        uint256 lastWatered;
        uint8 waterLevel;
        bool isDead;
    }

    mapping (uint8 => Plant) public plants;
    mapping (address => uint64[]) public userPlants;
    uint8 public plantCounter;
    address public owner;

    uint64 private constant PLANT_PRICE = 0.001 ether; // Wei
    uint64 private constant HARVEST_REWARD = 0.003 ether; // Wei
    uint8 private constant STAGE_DURATION = 1 minutes; // 1 minutes
    uint8 private constant WATER_DEPLETION_TIME = 30 seconds; // 30 seconds
    uint8 private constant WATER_DEPLETION_RATE = 2;

    event PlantSeeded(address indexed owner, uint8 indexed plantId);
    event PlantWatered(uint8 indexed plantId, uint8 newWaterLevel);
    event PlantHarvested(uint8 indexed plantId, address indexed owner, uint64 reward);
    event StageAdvanced(uint8 indexed plantId, GrowthStage newStage);
    event PlantDied(uint8 indexed plantId);

    modifier isPlantExist (uint8 _plantId) {
        require(plants[_plantId].id != 0, "Tanaman gaada!");
        _;
    }

    modifier onlyPlantOwner(uint8 _plantId) {
        require(plants[_plantId].owner == msg.sender, "Bukan tanaman Anda!");
        _;
    }

    modifier isAlive(uint8 _plantId) {
        require(!!!plants[_plantId].isDead, "Tanaman sudah mati!");
        _;
    }

    modifier isBlooming(uint8 _plantId) {
        require(plants[_plantId].stage == GrowthStage.BLOOMING, "Tanaman anda belum berbuah");
        _;
    }

    constructor () {
        owner = msg.sender;
    }

    function plantSeed() external payable returns (uint8) { 
        require(msg.value >= PLANT_PRICE, "Duit lau ora cukup");

        Plant memory _tempPlant = Plant({
            id: ++plantCounter,
            owner: msg.sender,
            stage: GrowthStage.SEED,
            plantedDate: block.timestamp,
            lastWatered: 0,
            waterLevel: 0,
            isDead: false
        });

        plants[_tempPlant.id] = _tempPlant;

        userPlants[msg.sender].push(_tempPlant.id);

        emit PlantSeeded(msg.sender, _tempPlant.id);

        return _tempPlant.id;
    }

    function updatePlantStage(uint8 _plantId) internal {
    Plant storage _plant = plants[_plantId]; 

    if (_plant.stage == GrowthStage.SEED) {
        _plant.stage = GrowthStage.SPROUT;
    } else if (_plant.stage == GrowthStage.SPROUT) {
        _plant.stage = GrowthStage.GROWING;
    } else if (_plant.stage == GrowthStage.GROWING) {
        _plant.stage = GrowthStage.BLOOMING;
    }

    emit StageAdvanced(_plantId, _plant.stage);
}

    function calculateWaterLevel(uint8 _plantId) public view returns (uint256) { 
        Plant memory _tempPlant = plants[_plantId];

        if (_tempPlant.id == 0 || !_tempPlant.isDead) {
            return 0;
        }

        uint256 lastWateredTime = block.timestamp - _tempPlant.lastWatered;
        uint256 depletionInterval = lastWateredTime / WATER_DEPLETION_TIME;
        uint256 waterLost = depletionInterval * WATER_DEPLETION_RATE;

        return waterLost;
    }


    function updateWaterLevel(uint8 _plantId, uint8 _level) internal returns (uint8) { 
        Plant storage _tempPlant = plants[_plantId];
        
        _tempPlant.waterLevel = _level;
        _tempPlant.lastWatered = block.timestamp;
        
        return _level;
    }

    function waterPlant(uint8 _plantId) external 
    isPlantExist(_plantId)
    onlyPlantOwner(_plantId)
    isAlive(_plantId)
     {

        updateWaterLevel(_plantId, 100);

        updatePlantStage(_plantId);

        emit PlantWatered(_plantId, 100);
    }

    function harvestPlant(uint8 _plantId) external
    isPlantExist(_plantId)
    onlyPlantOwner(_plantId)
    isAlive(_plantId)
    isBlooming(_plantId)
    {
        plants[_plantId].isDead = true;

        (bool success, ) = plants[_plantId].owner.call{value: HARVEST_REWARD}("");
        require(success, "Failed to send ETH reward");
        
        emit PlantHarvested(_plantId, plants[_plantId].owner, HARVEST_REWARD);
    }

    function getPlant(uint8 _plantId) external view returns (Plant memory) { 
        return plants[_plantId];
    }

    function getUserPlants(address _owner) external view returns (uint64[] memory) { 
        return userPlants[_owner];
    }

    function withdraw() external {
        require(msg.sender == owner, "Only owner can withdraw");
        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success, "Failed to withdraw ETH");
    }

    receive() external payable {}
}