## Closing the Trust Gap (part 3)

In the [previous](./part1) [parts](./part2) of this series,
we saw how metadata can be used to improve the user
experience of wallet confirmation dialogs and
source verification.

This part explains how the decentralized source repository
that verifies the required files and makes them available
looks like under the hood and how you can use it.

As explained in the previous part, source files, abi, metadata
and other information is all hashed into the code of a contract.
This means we do not need to worry about the correctness of
the information, because we can

 - (1) always check that the hashes match up and
 - (2) even recompile the source code to check that the bytecode matches.

So all we need is contract developers to make their source code and
metadata available. As a bonus, we will create a directory where
metadata and other information about each contract can be retrieved
just by the contract's address. So you do not have to retrieve the bytecode from chain,
nor the other files via swarm or ipfs. Furthermore,
the service will make sure that the data is also kept online and retrievable
via ipfs and swarm.

### Architecture

The source code and metadata repository consists of four components:

 - monitor: watches the blockchain for newly deployed contracts and tries to collect hash-linked metadata and source from ipfs and swarm
 - injector: allows people to upload source code and metadata via a web interface
 - verifier: re-compiles contracts coming in from both monitor and injector and checks for 100% bytecode match
 - pinning services: Makes content available via ipfs / swarm / http

The proof-of-concept version of this system is deployed at [https://verification.komputing.org](https://verification.komputing.org)
and its source code can be found at [https://github.com/ethereum/source-verify/](https://github.com/ethereum/source-verify/).

#### Monitor

The monitor listens for new blocks on all chains. Whenever a new block is mined,
it looks for contract creation transactions, retrieves their bytecode,
extracts the metadata hash and queues the metadata hash for retrieval
from swarm or ipfs.
Once the metadata is retrieved, it queues all referenced sources for
retrieval from swarm or ipfs. If they are finally also retrieved,
the metadata json and the sources are forwarded to the verifier
to check that they compile to the bytecode of the new contract.

The monitor basically allows the metadata and source data to get
into the repository if it has been available on swarm or ipfs
around the time of contract deployment. This means that as a contract deployer,
you do not have to care that your metadata and source is available on
swarm or ipfs indefinitely, but just at the time of deployment.

One shortcoming of the monitor at the current time is that
it only works for contract creation transactions and not for
contracts created by other contracts. You have to use the injector
for that.

#### Injector

If you forgot to make your metadata and sources available at deployment time
or if you are dealing with a contract that has been deployed a while ago,
you can use the manual injector. It essentially works the same way
as the monitor, just that it is a website where you upload your files.

A proof-of-concept of the injector can be found at [https://verification.komputing.org](https://verification.komputing.org).

Because you are uploading the metadata file,
you do not have to select the compiler version, specify
the name of the contract you want verified or flatten the source.
The system will take care of selecting the right setting and
compiler version.

The final version will not only look nicer, it will also be even more
convenient: You just need to upload all the metadata and source files
of all the contracts you want to verify in one go. No need to select the
chain or address, no need to determine which source files belong
to which contract and so on. It is only about making the files available,
the system can sort out how they can be used.

#### Verifier

If we allow anyone to upload arbitrary files, the system is easily
prone to denial-of-service attacks. Instead, we only store files
that compile to contracts that are deployed on chain. This way,
there is a certain cost involved. You can still upload
more or less arbitrary data in comments of source files, but
there will probably be a restriction on the size of source files,
so we are relatively safe.

The job of the verifier will be to take a metadata file and the
corresponding source files, extract the compiler version and
options from the metadata file and re-compile the contract.
As a first step, the verifier can check that the metadata hash
in the compiled bytecode matches the hash of the metadata file.
This way, we already know that metadata file has been generated
by the compiler at some point. The next check will be to see
that the bytecode matches the one at a certain address on chain
(or just any address).

#### Pinning Service

The pinning service is responsible for taking the data that
was verified and publishing it via various means, e.g.
ipfs, swarm and just direct http.

One problem is that the directory always changes, so
metadata files can be retrieved via their hash and thus also
source files, but the list of all contracts cannot be
retrieved directly. We experimented with using ipns for that,
but it is not really usable as of now.

The best way here would be to publish the ipfs and swarm hashes
of the directory via some other means.

Furthermore, direct access via http is of course also supported.

Finally, interested people can clone the repository and help
making it available via ipfs and swarm to reduce
the bandwidth strain on the central server.

### How to Use It

What can be done with the source and metadata repository?

Of course, you can use it to just browse the source code of contracts.
Just go to [https://verification.komputing.org/repository/contract/mainnet/](https://verification.komputing.org/repository/contract/mainnet/) and select the address.
The list of sources is also something other services like auditing platforms,
static analysis tools and so on can build on top.

If you want to interface with some contract, you can download its ABI
(as part of the metadata.json)
to see how to format the parameters, for example for one of the DAI
contracts: [https://contractrepo.komputing.org/contract/mainnet/0x4D95A049d5B0b7d32058cd3F2163015747522e99/metadata.json](https://contractrepo.komputing.org/contract/mainnet/0x4D95A049d5B0b7d32058cd3F2163015747522e99/metadata.json)

And last but not least - the main use case - wallets can use it to
show more information about the contract a transaction goes to.
The flow is as follows:

If a transaction to a contract is to be confirmed, the wallet
downloads the metadata file for the contract (via the link above, for example).
Then it looks for the function whose four-byte selector matches the first
four byte of the transaction payload. Next, the transaction data
is decoded according to the ABI of that function. Then, the
``userdoc`` field is searched for the function to retrieve the
natspec documentation of the function. The natspec
is formatted according to the decoded parameters:
For example, if you call the function `setOwner(address _owner)`
which has a userdoc of

    Make `_owner` the new owner.

then the wallet decodes the actual address sent to the function
and substitutes `_owner` to show

    Make 0x1234...890a the new owner.

It could even use ENS to reverse-resolve the address.

Finally, the wallet could also show a link to the source code
of the contract.


### Takeaway

As a takeaway, note that there is so much more data out there
that we could use to improve the user experience.
Smart Contract source code, documentation and front-ends
should be better interleaved to reduce the required trust
in the front-end authors and in the way the front-end is
retrieved over the web.

All that is required from developers is to hold on to
the metadata and source files as they were when the contracts
were compiled for deployment and make them available via
the metadata and source code repository.

It would be nice if deployment tools could do this automatically,
maybe even by default, since Smart Contract source codes
are meant to be public.

Finally, if wallets integrate this feature, they could even
show a warning if the source is not available via the source
code repository to create an incentive to upload the source.
