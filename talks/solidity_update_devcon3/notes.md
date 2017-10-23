Language design is no fun
balance between functionality and safety / complexity of the language - nice features
not an issue for general-purpose languages for quite a while, but on blockchain: cost

For any person here, quite easy to find a single aspect of Solidity where we disagree on at least one of these three

--

Solidity: get usable high-level language on Ethereum fast
succeeded there, but resulted in quite hackish code
now: need to make the right decisions about Solidity's future

safe and cheap features that look high level
-> no surprises, i.e.
  - disallow copying large arrays just with assignment
  - different assignment operator for copy and reference

Formal verification does not help if it is not easy to use (more later)

access to low level features only through assembly,
for example "intermediate-level" .call will be removed because of the magic involved
also, formal verif will be able to handle inline assembly

--

new features:

simple smart contract like database
code looks a little repetitive, always bad
very soon: direct passing of structs, also via web3.js.

even more useful if register multiple at the same time
what do you do: one array for each attribute - extremely ugly

again: We could allow just appending directly, but people would be surprised by the gas costs,
better to see a loop explicitly

also return

--

Done via a full rewrite of the ABI encoder/decoder.
Talk about improvements in the compiler that made this possible.

more or less directly generate a stream of opcodes
stack machine: keep track what is where on the stack in comments
assertions about what we think about the stack (at compile time)
helper functions to generate reusable snippets, but all inlined

--

intermediate language called iulia.
Alex will talk in more detail
has functions, loops, variables, assignments
extensions: types (talk about mstore bug)

paired with string template engine:
code that handles encoding of any array type,
angle brackets will be replaced by code that depends on the actual array type

- much harder to get wrong (assign correct variable, etc)
- much faster to write and maintain (introducing a new variable was a mess before)
- easy to debug (resulting code is readable)
- easier to optimize (inlining, loop invariants, ...)

best thing: Inline assembly is the same language (without templates)

--

usable language requires good tooling

remix: debug past transactions, inspect variables, breakpoints,
 reference highlighting, etc.
 next up: refactoring

AST: parser result, static analysis, mutation testing:
 - code coverage is just syntactical coverage.
 - mutation testing performs semantical coverage by changing tiny parts of the code and expecting tests to fail

standard-json-io:
 - fine-grained control of compiler options in a reproducible manner
 - selection of compiler outputs
 - metadata hash part of contract code

Documentation:
 - important to stay accessible, many people not proficient in english,
   big spanish-speaking community
   same for chinese and russian?

--
Formal verification

Why3:

showed this code last year
validates that the sum of the balances is constant for transfers

 - almost as much additional why3 code as contract code
 - yet another language
 - external prover tool
 - allaspects of Solidity have to be fully mapped to why3
 - Problems with aliasing in arrays
 - People will not use complicated tools.
 - Easy to get it wrong (you have to check the code that checks the code...)
 - If people use complicated tools, others will not understand it.

--

- smt solver, not as powerful, but much easier to use
- example shows that sum of two involved balances before
  and after stay the same.

- no new language
- ties into existing require / assert mechanism for pre-/post-conditions
- assumes require expression and tries to prove assert expression

- Nothing can be done wrong.
- no user-interactive required in proof generation
- no complete semantic mapping required (assumes arbitraryness)

--
...

and the great thing: If it fails, it tells you why it failed:
--

How to fix it? Add an assumption. This will throw at runtime.

The SMT checker makes you think about where overflow can happen.

Important point: Do not just blindly fail on overflow, but
think about how to avoid it.

Problem with throwing on overflow is it can stall transactions
and thus lock money away forever.

This code con also lock away money, but at least it is visible
what the requirements are.

--

another example:

taken from Underhanded Solidity Coding Contest.

--

boring Programming language theory stuff,
let's end this talk with some
exciting math puzzles!

assert false: We want this to fail, so that we get
counter-examples.
Assert can only fail if it is reachable, Solver
tells us how to reach it.
