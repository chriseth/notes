## Closing the Trust Gap (part 2)

In [part 1](./part1) of this series, I explained how transaction
confirmation dialogs could look like. Instead of 

    0xc47f00270000000000000000000000000000000000000000000
    00000000000000000002000000000000000000000000000000000
    00000000000000000000000000000005436872697300000000000
    0000000000000000000000000000000000000000000

they could show

    This transaction calls setName("Chris"), which is documented
    by the developers of the contract as: 
    Sets the stored name to "Chris".

This would be a tremendous win both with regards to usability
and security.

In this part, we will see what the missing pieces in the ecosystem are
to get to that point.

## Metadata

The Solidity compiler has been producing an artefact called
"metadata" since version 0.4.7, which was released in December 2016.

The metadata is a json file that contains all information
that could be relevant for the users of contracts:

It includes the ABI, developer documentation,
the "userdoc", a link to the source code and more!
The "userdoc" is the text mentioned above to be shown in the confirmation dialog
in natspec format, so this means the metadata is all you need
to decode the transaction payload according to the ABI and show the
summary of what the called function does - you can
even provide a link to the source code just
in case the user wants to know more
about they contract they are interacting with!

Here is a compressed example of such a metadata file:

    {
      "version": 1,
      "compiler": { "version": "0.5.10+commit.5a6ea5b1" },
      "language": "Solidity",
      "output": {
        "abi": [ ... ],
        "devdoc": { ... },
        "userdoc": {
          "methods": {
            "renounceOwnership()": {
            "notice": "Renouncing to ownership will leave the contract with..."
            }
          }
        }
      },
      "settings": { ... },
      "sources": {
        "<stdin>": {
          "keccak256": "0x7e6642a1b3d0e53c6e8627...d1a1d71be8fcff81ad78c9cb7d",
          "urls": [
            "bzzr://8f60adf13709606ea0505e6e...4be538acb195eb2af54b78168d89f0",
            "dweb:/ipfs/QmdCHWXFndjuC33Czwh3yVfMX8QRM9FTpcYyP5vsWqdajy"
          ]
        }
      }
    }

## Problems

So the metadata file is closing the trust gap.
The only downside is that there are currently
two problems we have to overcome.

### Where to get the metadata file?

The first problem is that there is no real way
to obtain the metadata file. If wallets
had access to all metadata files of all contracts,
they would of course use it, but that is not
the case.

The Solidity compiler wanted to solve this problem
from the start, but it somehow did not work out as planned.

The idea was that the compiler appends the swarm
hash of the metadata file to the bytecode. This way,
wallets just have to retrieve the bytecode, search
for the swarm hash at its end and download the metadata file from swarm.

This would have worked perfectly, but swarm ist
just not ready yet to host files permanently.
We tried ipfs, it turned out that at least the
cloudfront gateway seems to keep files for
longer, but that is of course also not a real
solution to the problem.

The real solution will be provided in part 3,
so please stay tuned!

I mentioned that there are two problems, so
what is the second problem?

### Source verification

Have you ever verified a contract on Etherscan?
Did you use a flattener? By that I mean:
Did you actually modify the source code?

It turns out that you can change the source code
in any way you like, as long as it results in
the same bytcode and etherscan will still
show "exact match".

This means you can change the natspec comments,
internal variable names, internal function names,
names of contracts and so on.

I find this very alarming, especially since
etherscan only accepts the first contract
that produces matching bytecode and does not allow changes afterwards. So if
a malicious party uploads different source code
before you are able to, they can fool your users.

Of course you could say that if it compiles
to the same bytecode, there is nothing you can
do because both versions are source
versions of the bytecode in the same way.

But that is not true.

Etherscan tells you "exact match", but when
it compares bytecode, it actually ignores
the last bytes in the deployed bytecode,
the metadata hash.

There is a reason to it: If you do not use
the exact same source code up to every byte,
with the exact same
whitespace and comments, the source hash
and thus the metadata hash will be different.
The same is true for the compiler settings,
because they are also part of the metadata.

So it is rather difficult to recompile source
code such that also the metadata hash matches.

Only that this is also not true:

The thing is that if you just use the metadata
file itself as a basis for recompilation, you
do not even need to fiddle with the settings,
select the compiler version, flatten the source code
and so on. If the source code is available
on swarm or ipfs, all you really have to do is upload
the metadata file and nothing else. It is
all in the metadata file. It can even be
done in a way such that you do not
have to specify the contract address!

It gets better: In part 3 I will show you a system
where you only have to upload the metadata file
and the source files to ipfs and the
contract will be source-verified automatically,
you do not have to click a single button!

One takeaway from this article: **Hold on to
the metadata file produced by the compiler!**

So what about malicious actors that try to
verify modified source?

If you recompile the source code and do not
ignore the metadata hash but compare
the full bytecode instead, you can be sure that the
source is an exact match up to every single
line in the documentation because the
hash of the metadata is part of the bytecode
and the hash of the source is part of
the metadata.

There is no way to fool the user anymore.
The source is exactly the same as the one
used for compiling the deployed bytecode.
