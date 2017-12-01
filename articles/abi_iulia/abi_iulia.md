## The new ABI Encoder/Decoder and Optimizer 

### Motivation

The release notes of some of the previous Solidity releases kept on mentioning the new ABI encoder, which will enable you to use structs and arbitrarily nested arrays in function arguments and return values. Still, when people ask whether it can be finally used now, I have to politely decline and say it is not yet finished. The main reason why it takes a little longer is that we re-implemented it from scratch in a new programming language. In the following, I would like to explain the benefits of doing that and what the current progress is.

The previous ABI encoder component of the Solidity compiler generated EVM assembly directly. This has several drawbacks: It is quite easy to introduce errors, it is very hard to check that it works correctly, it is difficult to maintain and finally, it is not so easy to write an optimizing compiler for this part.

The following code is taken from the old ABI decoder:

    // first load from calldata and potentially convert to memory if arrayType is memory
    TypePointer calldataType = arrayType.copyForLocation(DataLocation::CallData, false);
    if (calldataType->isDynamicallySized())
    {
        // put on stack: data_pointer length
        CompilerUtils(m_context).loadFromMemoryDynamic(IntegerType(256), !_fromMemory);
        // stack: base_offset data_offset next_pointer
        m_context << Instruction::SWAP1 << Instruction::DUP3 << Instruction::ADD;
        // stack: base_offset next_pointer data_pointer
        // retrieve length
        CompilerUtils(m_context).loadFromMemoryDynamic(IntegerType(256), !_fromMemory, true);
        // stack: base_offset next_pointer length data_pointer
        m_context << Instruction::SWAP2;
        // stack: base_offset data_pointer length next_pointer
    }
    else
    {
        // leave the pointer on the stack
        m_context << Instruction::DUP1;
        m_context << u256(calldataType->calldataEncodedSize()) << Instruction::ADD;
    }

Since the EVM is a stack machine, you always have to keep track where the various values are stored when you write EVM assembly directly and because of that, there is a comment about the current stack layout in every second line. If you want to introduce a new variable, you have to go through the whole code and update it.

### The new ABI Encoder/Decoder

In contrast, this is a snippet of the code generating the new ABI encoder (and you will see why I say "generating the ABI encoder" instead of "of the ABI encoder" in a moment):

    function <functionName>(offset, end) -> array {
        if iszero(slt(add(offset, 0x1f), end)) { revert(0, 0) }
        let length := <retrieveLength>
        array := <allocate>(<allocationSize>(length))
        let dst := array
        <storeLength> // might update offset and dst
        let src := offset
        <staticBoundsCheck>
        for { let i := 0 } lt(i, length) { i := add(i, 1) }
        {
            let elementPos := <retrieveElementPos>
            mstore(dst, <decodingFun>(elementPos, end))
            dst := add(dst, 0x20)
            src := add(src, <baseEncodedSize>)
        }
    }

The code above is responsible for decoding any kind of array type and at the same time, it performs bounds checks and cleanup on the decoded elements, which the old decoder did not do. It is written in our new intermediate language called iulia and is actually just a template. The various strings in angle brackets like ``<retrieveLength>`` will be replaced depending on the concrete array type we want to decode.

Furthermore, the various small tasks like allocating memory, retrieving and storing the length of an array, cleanup of value types and so on, will be done in separate functions which are templates themselves. This makes the design very flexible and modular and most importantly easy to audit.

### The Optimizer

This modularity also has a drawback, which you will see if you take a look at the following code, which is the iulia code of the decoder for ``function f(uint, uint, uint) public {}`` with all templates expanded.

    function abi_decode_tuple_t_uint256t_uint256t_uint256(headStart, dataEnd) -> value0, value1, value2
    {
        switch slt(sub(dataEnd, headStart), 96)
        case 1 {
            revert(0, 0)
        }
        {
            let offset := 0
            value0 := abi_decode_t_uint256(add(headStart, offset), dataEnd)
        }
        {
            let offset := 32
            value1 := abi_decode_t_uint256(add(headStart, offset), dataEnd)
        }
        {
            let offset := 64
            value2 := abi_decode_t_uint256(add(headStart, offset), dataEnd)
        }
    }
    function abi_decode_t_uint256(offset, end) -> value
    {
        value := cleanup_revert_t_uint256(calldataload(offset))
    }
    function cleanup_revert_t_uint256(value) -> cleaned
    {
        cleaned := value
    }

Wait, why is there so much code? A human writing this manually would just use the much shorter function

    function abi_decode_tuple_t_uint256t_uint256t_uint256(headStart, dataEnd) -> value0, value1, value2
    {
        if iszero(slt(sub(dataEnd, headStart), 0x60)) { revert(0, 0) }
        value0 := calldataload(0)
        value1 := calldataload(0x20)
        value2 := calldataload(0x40)
    }

It actually turns out that these two snippts of code are semantically equivalent. The many functions above are generated because of the modularity of the decoder and it would be really bad for the gas costs of the contract if this would be the final code the contract is compiled to.

Luckily, compilers have a stage called the "optimizer", which takes code (usually written in the intermediate language) and transforms it into shorter or faster code that has exactly the same behaviour. We are currently working on the optimizer for iulia, especially the "inlining expansion" component. Such a component looks for function calls satisfying a certain criterion (for example that they call a function which is very short) and replace the function call by the code of the function itself. The function ``cleanup_revert_t_uint256`` above is especially suitable for inlining because it does exactly nothing. For integer types shorter than 256 bytes, the decoder has to clean the value, but there is not nothing to be done for full 256 bit integers. Also ``abi_decode_t_uint256`` should be inlined, since it only contains a single instruction after ``cleanup_revert_t_uint256`` has been inlined. The code would look as follows after the function inlining step and removal of unused functions:

    function abi_decode_tuple_t_uint256t_uint256t_uint256(headStart, dataEnd) -> value0, value1, value2
    {
        switch slt(sub(dataEnd, headStart), 96)
        case 1 {
            revert(0, 0)
        }
        {
            let offset := 0
            value0 := calldataload(offset)
        }
        {
            let offset := 32
            value1 := calldataload(offset)
        }
        {
            let offset := 64
            value2 := calldataload(offset)
        }
    }

This is already almost where we want to go. We only need to do one additional step we call "variable elimination" or "rematerialization". It will replace a referenced variable by the expression that is currently assigned to it. This is especially useful if the variable is used only once or its value is a constant. After this step, we have the following code:

    function abi_decode_tuple_t_uint256t_uint256t_uint256(headStart, dataEnd) -> value0, value1, value2
    {
        switch slt(sub(dataEnd, headStart), 96)
        case 1 {
            revert(0, 0)
        }
        {
            value0 := calldataload(0)
        }
        {
            value1 := calldataload(32)
        }
        {
            value2 := calldataload(64)
        }
    }

Apart from the extra blocks and the ``switch`` instead of the ``if``, this is the same code as the one written manually above.

### Conclusion

As you have hopefully seen from this small example, it is possible to follow what the new optimizer does and whether it does everything correctly. Because the code still contains loops, functions, variables and expressions, everything stays more or less readable. Furthermore, the expressions keep the code well suited for stack-based machines like the EVM or WebAssembly machine.

The previous EVM assembly based optimizer had a symbolic execution stage where it would build up its own impression of the code in memory and then re-generated the code from scratch in an optimized way. You can probably imagine that in this old optimizer, bugs were extremly hard to fix, especially when compared to the new optimizer. Because of that, we just turned off all of the stages of the old optimizer we were not confident in anymore.

Of course the long-term goal is to use iulia in all parts of the compiler and not just the ABI encoder/decoder, but that part is a fairly isolated but yet complicated enough aspect of the Solidity compiler so that it makes to try it out there.