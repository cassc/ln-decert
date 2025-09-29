为 Bank 合约 编写测试。

测试Case 包含：

断言检查存款前后用户在 Bank 合约中的存款额更新是否正确。
检查存款金额的前 3 名用户是否正确，分别检查有1个、2个、3个、4 个用户， 以及同一个用户多次存款的情况。
检查只有管理员可取款，其他人不可以取款。


```
git clone git@github.com:cassc/ln-decert.git
cd ln-decert/4-foundry/2-test
forge test


Ran 3 tests for test/Bank.t.sol:BankTest
[PASS] testDepositUpdatesUserBalance() (gas: 78477)
[PASS] testTopDepositorsWithVaryingUsersAndRepeatDeposits() (gas: 282113)
[PASS] testWithdrawOnlyAdminCanCall() (gas: 123037)
Suite result: ok. 3 passed; 0 failed; 0 skipped; finished in 4.00ms (2.00ms CPU time)
```