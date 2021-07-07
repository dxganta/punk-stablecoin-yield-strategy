from brownie import *
from dotmap import DotMap


def main():
    return deploy()


def deploy():
    dai = "0x6B175474E89094C44Da98b954EedeAC495271d0F"
    deployer = accounts[0]

    strategy = StableCoinStrategy.deploy({"from": deployer})
    strategy.initialize(
        dai,
        deployer
    )

    # Uniswap some DAI Tokens to deployer for testing
    router = Contract.from_explorer(
        "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D")
    router.swapExactETHForTokens(
        0,  #  Mint out
        ["0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", dai],
        strategy,
        9999999999999999,
        {"from": deployer, "value": 10000000000000000000}
    )

    return DotMap(
        deployer=deployer,
        strategy=strategy
    )
