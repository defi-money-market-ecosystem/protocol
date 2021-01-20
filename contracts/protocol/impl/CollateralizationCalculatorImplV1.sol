/*
 * Copyright 2020 DMM Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

pragma solidity ^0.5.0;

import "../../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";
import "../../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../constants/CommonConstants.sol";

import "../interfaces/ICollateralizationCalculator.sol";
import "../interfaces/IDmmControllerV2.sol";
import "../interfaces/IDmmToken.sol";
import "../interfaces/IOwnable.sol";

contract CollateralizationCalculatorImplV1 is ICollateralizationCalculator {

    address public dmmController;
    address public timelock;

    using SafeMath for uint;

    constructor (
        address _dmmController,
        address _timelock
    ) public {
        dmmController = _dmmController;
        timelock = _timelock;
    }

    function setDmmController(
        address newDmmController
    ) external {
        if (dmmController != address(0)) {
            // This if statement is used for initialization
            require(
                msg.sender == timelock,
                "CollateralizationCalculatorImplV1::setDmmController: UNAUTHORIZED"
            );
        }
        _setDmmController(newDmmController);
    }

    function getTotalCollateralization() external view returns (uint) {
        IDmmControllerV2 _dmmController = IDmmControllerV2(dmmController);
        uint totalLiabilities = 0;
        uint totalAssets = 0;
        uint interestRateBaseRate = _dmmController.INTEREST_RATE_BASE_RATE();
        uint [] memory dmmTokenIds = _dmmController.getDmmTokenIds();
        for (uint i = 0; i < dmmTokenIds.length; i++) {
            IDmmToken dmmToken = IDmmToken(_dmmController.getDmmTokenAddressByDmmTokenId(dmmTokenIds[i]));
            IERC20 underlyingToken = IERC20(_dmmController.getUnderlyingTokenForDmm(address(dmmToken)));

            uint currentExchangeRate = dmmToken.getCurrentExchangeRate();

            // The interest rate is annualized, so figuring out the exchange rate 1-year from now is as simple as
            // applying the current interest rate to the current exchange rate.
            uint futureExchangeRate = currentExchangeRate.mul(interestRateBaseRate.add(_dmmController.getInterestRateByDmmTokenAddress(address(dmmToken)))).div(interestRateBaseRate);

            uint totalSupply = IERC20(address(dmmToken)).totalSupply();

            uint underlyingLiabilitiesForTotalSupply = _getDmmSupplyValue(
                _dmmController,
                dmmToken,
                underlyingToken,
                totalSupply,
                futureExchangeRate
            );
            totalLiabilities = totalLiabilities.add(underlyingLiabilitiesForTotalSupply);

            uint underlyingAssetsForTotalSupply = _getDmmSupplyValue(
                _dmmController,
                dmmToken,
                underlyingToken,
                totalSupply,
                currentExchangeRate
            );
            totalAssets = totalAssets.add(underlyingAssetsForTotalSupply);
        }
        return _getCollateralization(_dmmController, totalLiabilities, totalAssets);
    }

    function getActiveCollateralization() external view returns (uint) {
        IDmmControllerV2 _dmmController = IDmmControllerV2(dmmController);
        uint totalLiabilities = 0;
        uint totalAssetsInDmmContract = 0;
        uint [] memory dmmTokenIds = _dmmController.getDmmTokenIds();
        for (uint i = 0; i < dmmTokenIds.length; i++) {
            IDmmToken dmmToken = IDmmToken(_dmmController.getDmmTokenAddressByDmmTokenId(dmmTokenIds[i]));
            IERC20 underlyingToken = IERC20(_dmmController.getUnderlyingTokenForDmm(address(dmmToken)));

            uint underlyingLiabilitiesValue = _getDmmSupplyValue(
                _dmmController,
                dmmToken,
                underlyingToken,
                dmmToken.activeSupply(),
                dmmToken.getCurrentExchangeRate()
            );
            totalLiabilities = totalLiabilities.add(underlyingLiabilitiesValue);

            uint underlyingAssetsValue = _getUnderlyingSupplyValue(
                _dmmController,
                underlyingToken,
                underlyingToken.balanceOf(address(dmmToken)),
                dmmToken.decimals()
            );
            totalAssetsInDmmContract = totalAssetsInDmmContract.add(underlyingAssetsValue);
        }
        return _getCollateralization(_dmmController, totalLiabilities, totalAssetsInDmmContract);
    }

    // *************************
    // ***** Internal Functions
    // *************************

    function _setDmmController(
        address newDmmController
    ) internal {
        require(
            IOwnable(newDmmController).owner() == timelock,
            "CollateralizationCalculatorImplV1::_setDmmController: INVALID_CONTROLLER_OWNER"
        );
        require(
            address(IDmmControllerV2(newDmmController).collateralizationCalculator()) == address(this),
            "CollateralizationCalculatorImplV1::_setDmmController: INVALID_CONTROLLER_COLLATERALIZATION_CALCULATOR"
        );

        address oldDmmController = dmmController;
        dmmController = newDmmController;
        emit DmmControllerChanged(oldDmmController, newDmmController);
    }

    function _getDmmSupplyValue(
        IDmmControllerV2 __dmmController,
        IDmmToken __dmmToken,
        IERC20 __underlyingToken,
        uint __dmmSupply,
        uint __currentExchangeRate
    ) private view returns (uint) {
        uint underlyingTokenAmount = __dmmSupply.mul(__currentExchangeRate).div(CommonConstants(address(dmmController)).EXCHANGE_RATE_BASE_RATE());
        // The amount returned must use 18 decimal places, regardless of the # of decimals this token has.
        uint standardizedUnderlyingTokenAmount;
        if (__dmmToken.decimals() == 18) {
            standardizedUnderlyingTokenAmount = underlyingTokenAmount;
        } else if (__dmmToken.decimals() < 18) {
            standardizedUnderlyingTokenAmount = underlyingTokenAmount.mul((10 ** (18 - uint(__dmmToken.decimals()))));
        } else /* decimals > 18 */ {
            standardizedUnderlyingTokenAmount = underlyingTokenAmount.div((10 ** (uint(__dmmToken.decimals()) - 18)));
        }
        return __dmmController.underlyingTokenValuator().getTokenValue(address(__underlyingToken), standardizedUnderlyingTokenAmount);
    }

    function _getUnderlyingSupplyValue(
        IDmmControllerV2 __dmmController,
        IERC20 __underlyingToken,
        uint __underlyingSupply,
        uint8 __decimals
    ) private view returns (uint) {
        // The amount returned must use 18 decimal places, regardless of the # of decimals this token has.
        uint standardizedUnderlyingTokenAmount;
        if (__decimals == 18) {
            standardizedUnderlyingTokenAmount = __underlyingSupply;
        } else if (__decimals < 18) {
            standardizedUnderlyingTokenAmount = __underlyingSupply.mul((10 ** (18 - uint(__decimals))));
        } else /* decimals > 18 */ {
            standardizedUnderlyingTokenAmount = __underlyingSupply.div((10 ** (uint(__decimals) - 18)));
        }
        return __dmmController.underlyingTokenValuator().getTokenValue(address(__underlyingToken), standardizedUnderlyingTokenAmount);
    }

    function _getCollateralization(
        IDmmControllerV2 __dmmController,
        uint __totalLiabilities,
        uint __totalAssets
    ) internal view returns (uint) {
        if (__totalLiabilities == 0) {
            return 0;
        }
        uint offchainAssetsValue = __dmmController.offChainAssetsValuator().getOffChainAssetsValue();
        uint collateralValue = offchainAssetsValue.add(__totalAssets).add(__dmmController.offChainCurrencyValuator().getOffChainCurrenciesValue());
        return collateralValue.mul(__dmmController.COLLATERALIZATION_BASE_RATE()).div(__totalLiabilities);
    }

}