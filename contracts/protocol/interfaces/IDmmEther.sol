pragma solidity ^0.5.0;

interface IDmmEther {

    /**
     * @return The address for WETH being used by this contract.
     */
    function wethToken() external view returns (address);

    /**
     * Sends ETH from msg.sender to this contract to mint mETH.
     */
    function mintViaEther() external payable returns (uint);

    /**
     * Redeems the corresponding amount of mETH (from msg.sender) for WETH instead of ETH and sends it to `msg.sender`
     */
    function redeemToWETH(uint amount) external returns (uint);

}