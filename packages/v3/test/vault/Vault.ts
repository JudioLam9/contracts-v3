import { NetworkToken } from '../../components/LegacyContracts';
import { TestVault } from '../../typechain';
import { expectRole, roles } from '../helpers/AccessControl';
import { ETH, TKN, BNT, NATIVE_TOKEN_ADDRESS, ZERO_ADDRESS } from '../helpers/Constants';
import { createSystem } from '../helpers/Factory';
import { shouldHaveGap } from '../helpers/Proxy';
import {
    transfer,
    getBalance,
    createTokenBySymbol,
    errorMessageTokenExceedsBalance,
    TokenWithAddress
} from '../helpers/Utils';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber } from 'ethers';
import { ethers } from 'hardhat';

const { Upgradeable: UpgradeableRoles } = roles;

let deployer: SignerWithAddress;
let sender: SignerWithAddress;
let target: SignerWithAddress;
let admin: SignerWithAddress;

describe('TestVault', () => {
    shouldHaveGap('TestVault');

    before(async () => {
        [deployer, sender, target, admin] = await ethers.getSigners();
    });

    describe('construction', () => {
        let testVault: TestVault;

        beforeEach(async () => {
            ({ testVault } = await createSystem());
        });

        it('should revert when attempting to reinitialize', async () => {
            await expect(testVault.initialize()).to.be.revertedWith('Initializable: contract is already initialized');
        });

        it('should be properly initialized', async () => {
            expect(await testVault.version()).to.equal(1);
            expect(await testVault.isPayable()).to.be.true;
            await expectRole(testVault, UpgradeableRoles.ROLE_ADMIN, UpgradeableRoles.ROLE_ADMIN, [deployer.address]);
        });

        it('should be able to receive ETH', async () => {
            const prevBalance = await getBalance({ address: NATIVE_TOKEN_ADDRESS }, testVault.address);

            const amount = BigNumber.from(1000);
            await deployer.sendTransaction({ value: amount, to: testVault.address });

            expect(await getBalance({ address: NATIVE_TOKEN_ADDRESS }, testVault.address)).to.equal(
                prevBalance.add(amount)
            );
        });
    });

    describe('withdrawing funds', async () => {
        let testVault: TestVault;
        let networkToken: NetworkToken;

        beforeEach(async () => {
            ({ testVault, networkToken } = await createSystem());
        });

        const testWithdraw = (symbol: string) => {
            let token: TokenWithAddress;
            const amount = 1_000_000;

            beforeEach(async () => {
                token = await createTokenBySymbol(symbol);
            });

            it('events', async () => {
                await expect(testVault.withdrawFunds(token.address, target.address, 0))
                    .to.emit(testVault, 'FundsWithdrawn')
                    .withArgs(token.address, deployer.address, target.address, 0);
            });

            it('balance', async () => {
                await transfer(deployer, { address: token.address }, testVault.address, amount);

                const currentBalance = await getBalance({ address: token.address }, target);

                await expect(testVault.withdrawFunds(token.address, target.address, amount))
                    .to.emit(testVault, 'FundsWithdrawn')
                    .withArgs(token.address, deployer.address, target.address, amount);

                expect(await getBalance({ address: token.address }, target)).to.equal(currentBalance.add(amount));
            });

            context('errors', () => {
                it('should revert when withdrawing tokens to an invalid address', async () => {
                    await expect(testVault.withdrawFunds(token.address, ZERO_ADDRESS, amount)).to.be.revertedWith(
                        'InvalidAddress'
                    );
                });

                it('should allow withdrawing 0 tokens', async () => {
                    const prevVaultBalance = await getBalance(token, testVault.address);

                    await testVault.withdrawFunds(token.address, target.address, BigNumber.from(0));

                    expect(await getBalance(token, testVault.address)).to.equal(prevVaultBalance);
                });

                it('should revert when trying to withdraw more tokens than the vault holds', async () => {
                    await expect(
                        testVault.withdrawFunds(
                            token.address,
                            target.address,
                            (await getBalance({ address: token.address }, testVault.address)).add(1)
                        )
                    ).to.be.revertedWith(errorMessageTokenExceedsBalance(symbol));
                });
            });
        };

        for (const symbol of [BNT, ETH, TKN]) {
            context(symbol, () => testWithdraw(symbol));
        }

        it('when not allowed', async () => {
            await expect(
                testVault.connect(target).withdrawFunds(networkToken.address, target.address, 0)
            ).to.revertedWith('AccessDenied');
        });

        context('when paused', () => {
            it('should succeed when contract is not paused', async () => {
                await expect(testVault.withdrawFunds(networkToken.address, target.address, 0)).to.not.reverted;
            });

            it('should fail when contract is paused', async () => {
                await testVault.pause();

                await expect(testVault.withdrawFunds(networkToken.address, target.address, 0)).to.revertedWith(
                    'Pausable: paused'
                );
            });
        });
    });

    describe('pausing/unpausing', () => {
        let testVault: TestVault;

        beforeEach(async () => {
            ({ testVault } = await createSystem());
        });

        const testPause = () => {
            it('should pause the contract', async () => {
                await testVault.connect(sender).pause();

                expect(await testVault.isPaused()).to.be.true;
            });

            context('when paused', () => {
                beforeEach(async () => {
                    await testVault.connect(deployer).grantRole(UpgradeableRoles.ROLE_ADMIN, admin.address);
                    await testVault.connect(admin).pause();

                    expect(await testVault.isPaused()).to.be.true;
                });

                it('should unpause the contract', async () => {
                    await testVault.connect(sender).unpause();

                    expect(await testVault.isPaused()).to.be.false;
                });
            });
        };

        const testPauseRestricted = () => {
            it('should revert when a non-admin is attempting to pause', async () => {
                await expect(testVault.connect(sender).pause()).to.be.revertedWith('AccessDenied');
            });

            context('when paused', () => {
                beforeEach(async () => {
                    await testVault.connect(deployer).grantRole(UpgradeableRoles.ROLE_ADMIN, admin.address);
                    await testVault.connect(admin).pause();

                    expect(await testVault.isPaused()).to.be.true;
                });

                it('should revert when a non-admin is attempting unpause', async () => {
                    await expect(testVault.connect(sender).unpause()).to.be.revertedWith('AccessDenied');
                });
            });
        };

        context('admin', () => {
            beforeEach(async () => {
                await testVault.connect(deployer).grantRole(UpgradeableRoles.ROLE_ADMIN, sender.address);
            });

            testPause();
        });

        context('regular account', () => {
            testPauseRestricted();
        });
    });
});
