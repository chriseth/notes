#!/usr/bin/python

import math

# sizes are always in bits
# Machine / problem parameters

# size of max used memory in bits
memory = 1024 * 1024
# number of computational steps
steps = 2048
# size of memory word loaded in one step (Merkle tree leaf size)
memoryWordSize = 1024
# internal state size, i.e. size of all registers and data loaded from memory in one step
internalSize = 1024

# Verification protocol parameters

# number of subdivisions in the binary / r-ary search in the steps
divisions = 2
# size of the hash function output
hashSize = 256
# number of child nodes in the Merkle tree
merkleArity = 2
# whether the Merkle proof is performed directly (true) or interactively (false)
merkleDirect = True
# number of divisions in the binary / r-ary search in the Merkle proof
merkleSearchDivisions = 2

def log(n, base = 2):
    return int(math.ceil(math.log(n) / math.log(base)))

def complexity():
    # find the invalid step
    # prover posts `(divisions - 1)` state hashes (-> `divisions` ranges)
    # verifier selects one range until range size is zero
    rounds = log(steps, divisions)
    challengerMsgSizes = [log(divisions)] * rounds
    proverMsgSizes = [(divisions - 1) * hashSize] * rounds

    merkleLeaves = math.ceil(memory / memoryWordSize)
    merkleDepth = log(merkleLeaves, merkleArity)
    if merkleDirect:
        # prover posts internal pre- and post-state plus Merkle proof(s)
        merkleProofSize = merkleDepth * (merkleArity - 1) * hashSize
        proverMsgSizes += [
            internalSize * 2 +
            memoryWordSize +
            merkleProofSize
        ]
        challengerMsgSizes += [0]
    else:
        # prover posts internal pre- and post-state
        proverMsgSizes += [internalSize * 2 + memoryWordSize]
        # in the worst case, the post- merkle root is fake, but
        # we have to go back to the (correct) pre-root
        rounds = log(merkleDepth, merkleSearchDivisions) * 2
        proverMsgSizes += \
            [hashSize * (merkleSearchDivisions - 1)] * rounds + \
            [(merkleArity - 1) * hashSize] * 2
        challengerMsgSizes += [log(merkleSearchDivisions)] * rounds + [1, 1]
    return (proverMsgSizes, challengerMsgSizes)

def statistics():
    if merkleDirect:
        print "%d-ary search, direct proof in %d-ary tree:" % (
            divisions, merkleArity
        )
        merkleLeaves = math.ceil(memory / memoryWordSize)
        merkleDepth = log(merkleLeaves, merkleArity)
        print "Number of hash computations: %d" % (merkleDepth + 2)
    else:
        print "%d-ary search, interactive proof in %d-ary tree with %d-ary search:" % (
            divisions, merkleArity, merkleSearchDivisions
        )

    (pro, chal) = complexity()
    toBytes = lambda x: int(math.ceil(x / 8.0))
    print "%d rounds, max %d / %d bytes, %d / %d bytes total" % (
        len(pro), toBytes(max(pro)), toBytes(max(chal)), toBytes(sum(pro)), toBytes(sum(chal))
    )


