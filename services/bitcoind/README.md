
### Auth

Generate credentials with

`curl 'https://raw.githubusercontent.com/bitcoin/bitcoin/master/share/rpcauth/rpcauth.py' | python3 /dev/stdin [USERNAME]`


Credentials can be placed in

* `credentials/bitcoind/rpcauth/USERNAME` - RPC auth line after `rpcauth=USERNAME:` Just the salt/password portion!
`credentials/bitcoind/rpcauth/[USERNAME]` -
