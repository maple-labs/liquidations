// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

interface ILiquidations {

    // Support multiple AMMs for liquidation.
    struct MarketPlace {
        // Unique AMM identifier.
        bytes32 ammId;
        // Contract address that facilitate the interaction with AMM.
        address interactor;
        // ammPath [fromAsset][toAsset][facilitatorAsset].
        mapping(address => mapping (address => address)) ammPath;
    }

    event MarketPairAdded(bytes32 ammId, address fromAsset, address toAsset, address facilitatorAsset);
    event NewMarketAdded (bytes32 ammId, address router);

    function globals() external returns(address);

    function addMarketPair(bytes32 ammId, address fromAsset_, address toAsset_, address facilitatorAsset_) external;

    function addMarketPlace(bytes32 ammId_, address router_) external;

    function triggerDefault(
        address collateralAsset,
        address liquidityAsset,
        address loan
    ) 
        external
        returns (
            uint256 amountLiquidated,
            uint256 amountRecovered
        );

    function triggerDefaultWithAmmId(
        address collateralAsset,
        address liquidityAsset,
        address loan,
        bytes32 ammId
    )
        external
        returns (
            uint256 amountLiquidated,
            uint256 amountRecovered
        ); 


}