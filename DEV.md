## Sequence Diagram

### Interact with Vault (Deposit → Withdraw assets)

```mermaid
sequenceDiagram
    participant alice as Alice
    participant vault as Vault.sol
    participant aave as AAVE YieldVault

    alice ->> vault: deposit underlying asset
    vault ->> alice: mint shares based on deposited amounts
    vault ->> aave: call deposit() on YieldVault contract(ERC4626)
		aave ->> vault: mint shares to vault contract
    aave ->> aave: generate yield
		Note over alice, aave: certain periods

		alice ->> vault: call withdraw(): user can withdrawv deposited assset whenever they want
		vault ->> vault: burn shares
		vault ->> aave :withdraw(), redeem()
		aave ->> aave: burn shares
		aave ->> alice: return assets
```

### Determine winning team → distribute prize

```
sequenceDiagram

participant users as Users
participant admin as Admin
participant db as DB
participant vault as Vault.sol


admin ->> db: fetch()
db->> admin: returns point, deposited amount, team status etc...
admin ->> vault: execute draw()
vault->>vault: validate
alt if draw() execute transfer
vault ->> users: transfer prizes based on merkle tree
else if inidividual call claimPrize()
users ->> vault : call claimPrize()
vault ->> users: transfer prize
end
```
