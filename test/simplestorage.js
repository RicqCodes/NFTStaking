let simpleStorageInstance;

const SimpleStorage = artifacts.require("Keys");

contract("Keys", accounts => {

  beforeEach(async () => {
    keysInstance = await Keys.new();
  })

  it("...should store the value 89.", async () => {
    // Set value of 89
//     const tx = await keysInstance.set(89, { from: accounts[0]});

//     // Get stored value
//     const storedData = await keysInstance.get.call();

//     assert.equal(storedData, 89, "The value 89 was not stored.");
//   });
// });
