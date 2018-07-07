// setup and state
let web3 = new Web3(new Web3.providers.HttpProvider("http://127.0.0.1:9545/"));

let rps;
const DEPOSIT_AMOUNT = 25;
const BET_AMOUNT = 100;
const REVEAL_SPAN = 10;

// selectors
let deployButton = () => document.getElementById("deploy-contract");
let addressDropDown = () => document.getElementById("address-selector");
let deployedContractAddress = () => document.getElementById("deployed-contract-address");
let gameContainer = () => document.getElementById("game-container");
let playerSelector = () => document.getElementById("player-selector");
let commitmentChoice = () => document.getElementById("commitment-choice");
let commitmentRand = () => document.getElementById("commit-random-number");
let commitButton = () => document.getElementById("commit");
let commitmentsMade = () => document.getElementById("commitments-made");
let revealChoice = () => document.getElementById("reveal-choice");
let revealRand = () => document.getElementById("reveal-random-number");
let revealButton = () => document.getElementById("reveal");
let revealsMade = () => document.getElementById("reveals-made");
let distributeButton = () => document.getElementById("distribute");
let distributeResults = () => document.getElementById("distribute-results");

// initial population
let populateAddresses = async element => {
    let accounts = await web3.eth.getAccounts();
    element.innerHTML = accounts.map(a => createAddressOption(a)).reduce((a, b) => a + b);
};

let createAddressOption = address => {
    return `<option value=${address}>${address}</option>`;
};

// util
let choiceToNumber = choiceString => {
    if (choiceString == "rock") return 1;
    if (choiceString == "paper") return 2;
    if (choiceString == "scissors") return 3;
    throw new Error("unrecognised choice");
};

// event handlers
async function deployNewContract(bytecode, abi, betAmount, depositAmount, revealSpan, deployingAccount) {
    let rockPaperScissors = new web3.eth.Contract(abi);
    return await rockPaperScissors
        .deploy({
            data: bytecode,
            arguments: [betAmount, depositAmount, revealSpan]
        })
        .send({
            from: deployingAccount,
            gas: 2000000,
            gasPrice: 1
        });
}

let deployHandler = async () => {
    let addressSelection = addressDropDown().value;
    console.log("Address selected for deployment:", addressSelection);

    let deployedContract = await deployNewContract(
        RPS_BYTECODE,
        RPS_ABI,
        BET_AMOUNT,
        DEPOSIT_AMOUNT,
        REVEAL_SPAN,
        addressSelection
    );
    console.log("Contract deployed at:", deployedContract.options.address);

    rps = deployedContract;
    deployedContractAddress().innerHTML = `Contract deployed at: <b>${rps.options.address}</b>`;
    gameContainer().hidden = false;
};

let commitHandler = async () => {
    // get the player
    let player = playerSelector().value;

    // get the choice and the rand
    let choice = choiceToNumber(commitmentChoice().value);
    let rand = web3.utils.fromAscii(commitmentRand().value);

    let commitment = web3.utils.soliditySha3(
        { t: "address", v: player },
        { t: "uint8", v: choice },
        { t: "bytes32", v: rand }
    );
    console.log(`Player: ${player} making commitment : ${commitment}`);

    // make the commitment
    let transactionReceipt = await rps.methods
        .commit(commitment)
        .send({ from: player, value: BET_AMOUNT + DEPOSIT_AMOUNT, gas: 200000 });
    console.log("Commitment mined in transaction: ", transactionReceipt);

    // wipe the selections
    commitmentChoice().value = -1;
    commitmentRand().value = "";

    // add an entry to the commitments-made
    let li = document.createElement("li");
    li.appendChild(document.createTextNode(`Player: ${player} made commitment: ${commitment}`));
    commitmentsMade().appendChild(li);
};

let revealHandler = async () => {
    // get the player
    let player = playerSelector().value;

    // get the choice and the rand
    let choice = choiceToNumber(revealChoice().value);
    let rand = web3.utils.fromAscii(revealRand().value);

    //TODO: interesting constraint on the ordering here:
    console.log(`Player: ${player} revealing choice: ${choice} with blinding factor: ${rand}`);

    // make the commitment
    let transactionReceipt = await rps.methods.reveal(choice, rand).send({ from: player });
    console.log("Reveal mined in transaction: ", transactionReceipt);

    // wipe the selections
    revealChoice().value = -1;
    revealRand().value = "";

    // add an entry to the commitments-made
    let li = document.createElement("li");
    li.appendChild(
        document.createTextNode(`Player: ${player} revealed choice: ${choice} with blinding factor: ${rand}`)
    );
    revealsMade().appendChild(li);
};

let distributeHandler = async () => {
    // get the player
    let player = playerSelector().value;
    // call distribute
    let transactionReceipt = await rps.methods.distribute().send({ from: player, gas: 200000 });
    console.log("Distribute mined in transaction: ", transactionReceipt);
    let balances = transactionReceipt.events["Payout"].map(e => {
        return {
            player: e.returnValues.player,
            amount: e.returnValues.amount
        };
    });

    balances.forEach(b => {
        let li = document.createElement("li");
        li.appendChild(document.createTextNode(`Player: ${b.player} has received: ${b.amount}.`));
        distributeResults().appendChild(li);
    });
};

// initialise
document.addEventListener("DOMContentLoaded", function(event) {
    // populate the address list
    populateAddresses(addressDropDown());

    // set the handler on the deploy
    deployButton().addEventListener("click", deployHandler);

    // populate the players
    populateAddresses(playerSelector());

    // commit handler
    commitButton().addEventListener("click", commitHandler);

    // reveal handler
    revealButton().addEventListener("click", revealHandler);

    // distribute handler
    distributeButton().addEventListener("click", distributeHandler);
});
