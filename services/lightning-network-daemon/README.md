

# Daemon Bootstrap

```
lncli create

```

# Configuration

`externalhosts` can be set wit Consul key `credentials/lightning-network-daemon/externalhosts`

## Auto unlock (optional)

Set `wallet_unlock_password` to the wallet unlock password


## CLI

`lncli --tlscertpath=/alloc/data/tls/tls.cert --macaroonpath=/alloc/data/chain/bitcoin/mainnet/admin.macaroon ...`


## New Address

`lncli --tlscertpath=/alloc/data/tls/tls.cert --macaroonpath=/alloc/data/chain/bitcoin/mainnet/admin.macaroon newaddress p2wkh`

