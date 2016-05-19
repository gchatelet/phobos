/**
Computes MurmurHash hashes of arbitrary data. MurmurHash is a non-cryptographic
hash function suitable for general hash-based lookup. It is optimized for x86
but can be used on every architectures.

The current version is MurmurHash3, which yields a 32-bit or 128-bit hash value.
The older MurmurHash 1 and 2 are currently not supported.

MurmurHash3 comes in three flavors, providing greater and greater throughput:
$(UL
$(LI $(D MurmurHash3_32_opt32) produces a 32-bit value and is optimized for 32-bit architectures,)
$(LI $(D MurmurHash3_128_opt32) produces a 128-bit value and is optimized for 32-bit architectures,)
$(LI $(D MurmurHash3_128_opt64) produces a 128-bit value and is optimized for 64-bit architectures.)
)

Note:
$(UL
$(LI $(D MurmurHash3_128_opt32) and $(D MurmurHash3_128_opt64) produce different
  values.)
$(LI The current implementation is optimized for little endian architectures.
  It will exhibit different results on big endian architectures and a slightly
  less uniform distribution.)
)

This module conforms to the APIs defined in $(D std.digest.digest).

This module publicly imports $(D std.digest.digest) and can be used as a stand-alone module.

License: $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Guillaume Chatelet
References: $(LINK2 https://code.google.com/p/smhasher/wiki/MurmurHash3, Reference implementation)
$(BR) $(LINK2 https://en.wikipedia.org/wiki/MurmurHash, Wikipedia)
*/
/* Copyright Guillaume Chatelet 2016.
 * Distributed under the Boost Software License, Version 1.0.
 * (See LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
 */
module std.digest.murmurhash;

///
unittest
{
    // MurmurHash3_32_opt32, MurmurHash3_128_opt32 and MurmurHash3_128_opt64 implement
    // the std.digest.digest Template API.
    static assert(isDigest!MurmurHash3_32_opt32);
    // The convenient digest template allows for quick hashing of any data.
    ubyte[4] hashed = digest!MurmurHash3_32_opt32([1, 2, 3, 4]);
}

///
unittest
{
    // One can also hash ubyte data piecewise by instanciating a hasher and call
    // the 'put' method.
    const(ubyte)[] data1 = [1, 2, 3];
    const(ubyte)[] data2 = [4, 5, 6, 7];
    // The incoming data will be buffered and hashed block by block.
    MurmurHash3_32_opt32 hasher;
    hasher.put(data1);
    hasher.put(data2);
    // The call to 'finish' ensures:
    // - the remaining bits are processed
    // - the hash gets finalized
    auto hashed = hasher.finish();
}

///
unittest
{
    // Using FastMurmurHash3_32_opt32, FastMurmurHash3_128_opt32 and
    // FastMurmurHash3_128_opt64 you gain full control over which part of the
    // algorithm to run.
    // This allows for maximum throughput but needs extra care.

    // Data type must be the same as the hasher's element type:
    // - uint for FastMurmurHash3_32_opt32
    // - ulong[2] for FastMurmurHash3_128_opt32 and FastMurmurHash3_128_opt64
    const(uint)[] data = [1, 2, 3, 4];
    // Note the hasher starts with 'Fast'.
    FastMurmurHash3_32_opt32 hasher;
    // Push as many array of elements as you need. The less calls the better.
    hasher.putBlocks(data);
    // Put remainder bytes if needed. This method can be called only once.
    hasher.putRemainder(ubyte(1), ubyte(1), ubyte(1));
    // Call finalize to incorporate data length in the hash.
    hasher.finalize();
    // Finally get the hashed value.
    auto hashed = hasher.getBytes();
}

public import std.digest.digest;

@safe:

/// MurmurHash3_32_opt32 $(D std.digest.digest) Template API.
alias MurmurHash3_32_opt32 = Piecewise!FastMurmurHash3_32_opt32;
/// MurmurHash3_128_opt32 $(D std.digest.digest) Template API.
alias MurmurHash3_128_opt32 = Piecewise!FastMurmurHash3_128_opt32;
/// MurmurHash3_128_opt64 $(D std.digest.digest) Template API.
alias MurmurHash3_128_opt64 = Piecewise!FastMurmurHash3_128_opt64;

/// MurmurHash3_32_opt32 $(D std.digest.digest.Digest) OOO API.
alias MurmurHash3_32_opt32Digest = WrapperDigest!MurmurHash3_32_opt32;
/// MurmurHash3_128_opt32 $(D std.digest.digest.Digest) OOO API.
alias MurmurHash3_128_opt32Digest = WrapperDigest!MurmurHash3_128_opt32;
/// MurmurHash3_128_opt64 $(D std.digest.digest.Digest) OOO API.
alias MurmurHash3_128_opt64Digest = WrapperDigest!MurmurHash3_128_opt64;

/*
Performance notes:
 - To help a bit with the performance when compiling with DMD some functions in
   this module have been duplicated, some other functions have been rewritten to
   pass by value instead of by reference.
 - GDC and LDC are on par with their C++ counterpart.
 - DMD is typically between 20% to 50% of the GCC version.
 -
*/

/++
MurmurHash3 optimized for x86 processors producing a 32-bit value.

This is a lower level implementation that makes finalization optional and have
better performance than $(D digest).
Note that $(D putRemainder) can be called only once and that no subsequent calls
to $(D putBlocks) is allowed.
+/
struct FastMurmurHash3_32_opt32
{
private:
    enum uint c1 = 0xcc9e2d51;
    enum uint c2 = 0x1b873593;
    uint h1;

public:
    alias Block = uint; /// The element type for 32-bit implementation.
    size_t size;

    this(uint seed)
    {
        h1 = seed;
    }

    @disable this(this);

    /++
    Adds a single Block of data without increasing size.
    Make sure to increase size by Block.sizeof for each call to putBlock.
    +/
    void putBlock(uint block) pure nothrow @nogc
    {
        h1 = update(h1, block, 0, c1, c2, 15, 13, 0xe6546b64U);
    }

    /// Put remainder bytes. This must be called only once after putBlock and before finalize.
    void putRemainder(scope const(ubyte[]) data...) pure nothrow @nogc
    {
        assert(data.length < Block.sizeof);
        assert(data.length >= 0);
        size += data.length;
        uint k1 = 0;
        final switch (data.length & 3)
        {
        case 3:
            k1 ^= data[2] << 16;
            goto case;
        case 2:
            k1 ^= data[1] << 8;
            goto case;
        case 1:
            k1 ^= data[0];
            h1 ^= shuffle(k1, c1, c2, 15);
            goto case;
        case 0:
        }
    }

    /// Incorporate size and finalizes the hash.
    void finalize() pure nothrow @nogc
    {
        h1 ^= size;
        h1 = fmix(h1);
    }

    /// Returns the hash as an uint value.
    Block get() pure nothrow @nogc
    {
        return h1;
    }

    /++
    Pushes an array of blocks at once. It is more efficient to push as much data as possible in a single call.
    On platform that does not support unaligned reads (MIPS or old ARM chips), the compiler may produce slower code to ensure correctness.
    +/
    void putBlocks(scope const(Block[]) blocks...) pure nothrow @nogc
    {
        foreach (const block; blocks)
        {
            putBlock(block);
        }
        size += blocks.length * Block.sizeof;
    }

    /// Returns the current hashed value as an ubyte array.
    auto getBytes() pure nothrow @nogc
    {
        return cast(ubyte[Block.sizeof]) cast(uint[1])[get()];
    }
}

/++
MurmurHash3 optimized for x86 processors producing a 128-bit value.

This is a lower level implementation that makes finalization optional and have
better performance than $(D digest).
Note that $(D putRemainder) can be called only once and that no subsequent calls
to $(D putBlocks) is allowed.
+/
struct FastMurmurHash3_128_opt32
{
private:
    enum uint c1 = 0x239b961b;
    enum uint c2 = 0xab0e9789;
    enum uint c3 = 0x38b34ae5;
    enum uint c4 = 0xa1e38b93;
    uint h4, h3, h2, h1;

public:
    alias Block = uint[4]; /// The element type for 128-bit implementation.
    size_t size;

    this(uint seed4, uint seed3, uint seed2, uint seed1)
    {
        h4 = seed4;
        h3 = seed3;
        h2 = seed2;
        h1 = seed1;
    }

    this(uint seed)
    {
        h4 = h3 = h2 = h1 = seed;
    }

    @disable this(this);

    /++
    Adds a single Block of data without increasing size.
    Make sure to increase size by Block.sizeof for each call to putBlock.
    +/
    void putBlock(Block block) pure nothrow @nogc
    {
        h1 = update(h1, block[0], h2, c1, c2, 15, 19, 0x561ccd1bU);
        h2 = update(h2, block[1], h3, c2, c3, 16, 17, 0x0bcaa747U);
        h3 = update(h3, block[2], h4, c3, c4, 17, 15, 0x96cd1c35U);
        h4 = update(h4, block[3], h1, c4, c1, 18, 13, 0x32ac3b17U);
    }

    /// Put remainder bytes. This must be called only once after putBlock and before finalize.
    void putRemainder(scope const(ubyte[]) data...) pure nothrow @nogc
    {
        assert(data.length < Block.sizeof);
        assert(data.length >= 0);
        size += data.length;
        uint k1 = 0;
        uint k2 = 0;
        uint k3 = 0;
        uint k4 = 0;

        final switch (data.length & 15)
        {
        case 15:
            k4 ^= data[14] << 16;
            goto case;
        case 14:
            k4 ^= data[13] << 8;
            goto case;
        case 13:
            k4 ^= data[12] << 0;
            h4 ^= shuffle(k4, c4, c1, 18);
            goto case;
        case 12:
            k3 ^= data[11] << 24;
            goto case;
        case 11:
            k3 ^= data[10] << 16;
            goto case;
        case 10:
            k3 ^= data[9] << 8;
            goto case;
        case 9:
            k3 ^= data[8] << 0;
            h3 ^= shuffle(k3, c3, c4, 17);
            goto case;
        case 8:
            k2 ^= data[7] << 24;
            goto case;
        case 7:
            k2 ^= data[6] << 16;
            goto case;
        case 6:
            k2 ^= data[5] << 8;
            goto case;
        case 5:
            k2 ^= data[4] << 0;
            h2 ^= shuffle(k2, c2, c3, 16);
            goto case;
        case 4:
            k1 ^= data[3] << 24;
            goto case;
        case 3:
            k1 ^= data[2] << 16;
            goto case;
        case 2:
            k1 ^= data[1] << 8;
            goto case;
        case 1:
            k1 ^= data[0] << 0;
            h1 ^= shuffle(k1, c1, c2, 15);
            goto case;
        case 0:
        }
    }

    /// Incorporate size and finalizes the hash.
    void finalize() pure nothrow @nogc
    {
        h1 ^= size;
        h2 ^= size;
        h3 ^= size;
        h4 ^= size;

        h1 += h2;
        h1 += h3;
        h1 += h4;
        h2 += h1;
        h3 += h1;
        h4 += h1;

        h1 = fmix(h1);
        h2 = fmix(h2);
        h3 = fmix(h3);
        h4 = fmix(h4);

        h1 += h2;
        h1 += h3;
        h1 += h4;
        h2 += h1;
        h3 += h1;
        h4 += h1;
    }

    /// Returns the hash as an uint[4] value.
    Block get() pure nothrow @nogc
    {
        return [h1, h2, h3, h4];
    }

    /++
    Pushes an array of blocks at once. It is more efficient to push as much data as possible in a single call.
    On platform that does not support unaligned reads (MIPS or old ARM chips), the compiler may produce slower code to ensure correctness.
    +/
    void putBlocks(scope const(Block[]) blocks...) pure nothrow @nogc
    {
        foreach (const block; blocks)
        {
            putBlock(block);
        }
        size += blocks.length * Block.sizeof;
    }

    /// Returns the current hashed value as an ubyte array.
    auto getBytes() pure nothrow @nogc
    {
        return cast(ubyte[Block.sizeof]) get();
    }
}

/++
MurmurHash3 optimized for x86_64 processors producing a 128-bit value.

This is a lower level implementation that makes finalization optional and have
better performance than $(D digest).
Note that $(D putRemainder) can be called only once and that no subsequent calls
to $(D putBlocks) is allowed.
+/
struct FastMurmurHash3_128_opt64
{
private:
    enum ulong c1 = 0x87c37b91114253d5;
    enum ulong c2 = 0x4cf5ad432745937f;
    ulong h2, h1;

public:
    alias Block = ulong[2]; /// The element type for 128-bit implementation.
    size_t size;

    this(ulong seed)
    {
        h2 = h1 = seed;
    }

    this(ulong seed2, ulong seed1)
    {
        h2 = seed2;
        h1 = seed1;
    }

    @disable this(this);

    /++
    Adds a single Block of data without increasing size.
    Make sure to increase size by Block.sizeof for each call to putBlock.
    +/
    void putBlock(Block block) pure nothrow @nogc
    {
        h1 = update(h1, block[0], h2, c1, c2, 31, 27, 0x52dce729U);
        h2 = update(h2, block[1], h1, c2, c1, 33, 31, 0x38495ab5U);
    }

    /// Put remainder bytes. This must be called only once after putBlock and before finalize.
    void putRemainder(scope const(ubyte[]) data...) pure nothrow @nogc
    {
        assert(data.length < Block.sizeof);
        assert(data.length >= 0);
        size += data.length;
        ulong k1 = 0;
        ulong k2 = 0;
        final switch (data.length & 15)
        {
        case 15:
            k2 ^= ulong(data[14]) << 48;
            goto case;
        case 14:
            k2 ^= ulong(data[13]) << 40;
            goto case;
        case 13:
            k2 ^= ulong(data[12]) << 32;
            goto case;
        case 12:
            k2 ^= ulong(data[11]) << 24;
            goto case;
        case 11:
            k2 ^= ulong(data[10]) << 16;
            goto case;
        case 10:
            k2 ^= ulong(data[9]) << 8;
            goto case;
        case 9:
            k2 ^= ulong(data[8]) << 0;
            h2 ^= shuffle(k2, c2, c1, 33);
            goto case;
        case 8:
            k1 ^= ulong(data[7]) << 56;
            goto case;
        case 7:
            k1 ^= ulong(data[6]) << 48;
            goto case;
        case 6:
            k1 ^= ulong(data[5]) << 40;
            goto case;
        case 5:
            k1 ^= ulong(data[4]) << 32;
            goto case;
        case 4:
            k1 ^= ulong(data[3]) << 24;
            goto case;
        case 3:
            k1 ^= ulong(data[2]) << 16;
            goto case;
        case 2:
            k1 ^= ulong(data[1]) << 8;
            goto case;
        case 1:
            k1 ^= ulong(data[0]) << 0;
            h1 ^= shuffle(k1, c1, c2, 31);
            goto case;
        case 0:
        }
    }

    /// Incorporate size and finalizes the hash.
    void finalize() pure nothrow @nogc
    {
        h1 ^= size;
        h2 ^= size;

        h1 += h2;
        h2 += h1;
        h1 = fmix(h1);
        h2 = fmix(h2);
        h1 += h2;
        h2 += h1;
    }

    /// Returns the hash as an ulong[2] value.
    Block get() pure nothrow @nogc
    {
        return [h1, h2];
    }

    /++
    Pushes an array of blocks at once. It is more efficient to push as much data as possible in a single call.
    On platform that does not support unaligned reads (MIPS or old ARM chips), the compiler may produce slower code to ensure correctness.
    +/
    void putBlocks(scope const(Block[]) blocks...) pure nothrow @nogc
    {
        foreach (const block; blocks)
        {
            putBlock(block);
        }
        size += blocks.length * Block.sizeof;
    }

    /// Returns the current hashed value as an ubyte array.
    auto getBytes() pure nothrow @nogc
    {
        return cast(ubyte[Block.sizeof]) get();
    }
}

unittest
{
    // Pushing unaligned data and making sure the result is still coherent.
    void testUnalignedHash(H)()
    {
        immutable ubyte[1025] data = 0xAC;
        immutable alignedHash = digest!H(data[0 .. $ - 1]); // 0..1023
        immutable unalignedHash = digest!H(data[1 .. $]); // 1..1024
        assert(alignedHash == unalignedHash);
    }

    testUnalignedHash!MurmurHash3_32_opt32();
    testUnalignedHash!MurmurHash3_128_opt32();
    testUnalignedHash!MurmurHash3_128_opt64();
}

import std.traits : moduleName;

/*
This is a helper struct and is not intended to be used directly. MurmurHash
cannot put chunks smaller than Block.sizeof at a time. This struct stores
remainder bytes in a buffer and pushes it when the block is complete or during
finalization.
*/
struct Piecewise(Hasher) if (moduleName!Hasher == "std.digest.murmurhash")
{
    enum blockSize = bits!Block;

    alias Block = Hasher.Block;
    union BufferUnion
    {
        Block block;
        ubyte[Block.sizeof] data;
    }

    BufferUnion buffer;
    size_t bufferSize;
    Hasher hasher;

    // Initialize
    void start()
    {
        this = Piecewise.init;
    }

    /++
    Adds data to the digester. This function can be called many times in a row
    after start but before finish.
    +/
    void put(scope const(ubyte)[] data...) pure nothrow
    {
        // Buffer should never be full while entering this function.
        assert(bufferSize < Block.sizeof);

        // Check if we have some leftover data in the buffer. Then fill the first block buffer.
        if (bufferSize + data.length < Block.sizeof)
        {
            buffer.data[bufferSize .. bufferSize + data.length] = data[];
            bufferSize += data.length;
            return;
        }
        const bufferLeeway = Block.sizeof - bufferSize;
        assert(bufferLeeway <= Block.sizeof);
        buffer.data[bufferSize .. $] = data[0 .. bufferLeeway];
        hasher.putBlock(buffer.block);
        data = data[bufferLeeway .. $];

        // Do main work: process chunks of Block.sizeof bytes.
        const numBlocks = data.length / Block.sizeof;
        const remainderStart = numBlocks * Block.sizeof;
        foreach (const Block block; cast(const(Block[]))(data[0 .. remainderStart]))
        {
            hasher.putBlock(block);
        }
        // +1 for bufferLeeway Block.
        hasher.size += (numBlocks + 1) * Block.sizeof;
        data = data[remainderStart .. $];

        // Now add remaining data to buffer.
        assert(data.length < Block.sizeof);
        bufferSize = data.length;
        buffer.data[0 .. data.length] = data[];
    }

    /++
    Finalizes the computation of the hash and returns the computed value.
    Note that $(D finish) can be called only once and that no subsequent calls
    to $(D put) is allowed.
    +/
    ubyte[Block.sizeof] finish() pure nothrow
    {
        auto tail = getRemainder();
        if (tail.length > 0)
        {
            hasher.putRemainder(tail);
        }
        hasher.finalize();
        return hasher.getBytes();
    }

private:
    const(ubyte)[] getRemainder()
    {
        return buffer.data[0 .. bufferSize];
    }
}

unittest
{
    struct DummyHasher
    {
        alias Block = ubyte[2];
        const(Block)[] results;
        size_t size;

        void putBlock(Block value) pure nothrow
        {
            results ~= value;
        }

        void putRemainder(scope const(ubyte)[] data...) pure nothrow
        {
        }

        void finalize() pure nothrow
        {
        }

        Block getBytes() pure nothrow
        {
            return Block.init;
        }
    }

    auto digester = Piecewise!DummyHasher();
    assert(digester.hasher.results == []);
    assert(digester.getRemainder() == []);
    digester.put(0);
    assert(digester.hasher.results == []);
    assert(digester.getRemainder() == [0]);
    digester.put(1, 2);
    assert(digester.hasher.results == [[0, 1]]);
    assert(digester.getRemainder() == [2]);
    digester.put(3, 4, 5);
    assert(digester.hasher.results == [[0, 1], [2, 3], [4, 5]]);
    assert(digester.getRemainder() == []);
}

private template bits(T)
{
    enum bits = T.sizeof * 8;
}

private T rotl(T)(T x, uint y)
in
{
    import std.traits : isUnsigned;

    static assert(isUnsigned!T);
    debug assert(y >= 0 && y <= bits!T);
}
body
{
    return ((x << y) | (x >> (bits!T - y)));
}

private T shuffle(T)(T k, T c1, T c2, ubyte r1)
{
    import std.traits : isUnsigned;

    static assert(isUnsigned!T);
    k *= c1;
    k = rotl(k, r1);
    k *= c2;
    return k;
}

private T update(T)(ref T h, T k, T mixWith, T c1, T c2, ubyte r1, ubyte r2, T n)
{
    import std.traits : isUnsigned;

    static assert(isUnsigned!T);
    h ^= shuffle(k, c1, c2, r1);
    h = rotl(h, r2);
    h += mixWith;
    return h * 5 + n;
}

private uint fmix(uint h) pure nothrow @nogc
{
    h ^= h >> 16;
    h *= 0x85ebca6b;
    h ^= h >> 13;
    h *= 0xc2b2ae35;
    h ^= h >> 16;
    return h;
}

private ulong fmix(ulong k) pure nothrow @nogc
{
    k ^= k >> 33;
    k *= 0xff51afd7ed558ccd;
    k ^= k >> 33;
    k *= 0xc4ceb9fe1a85ec53;
    k ^= k >> 33;
    return k;
}

unittest {
    template hashFun(T) {
        alias hashFun = function (const ubyte[] blob, uint seed, ubyte[] output) {
            Piecewise!T piecewise;
            piecewise.hasher = T(seed);
            piecewise.put(blob);
            output[] = piecewise.finish();
        };
    }
    assert(VerificationTest(hashFun!FastMurmurHash3_32_opt32, 32, 0xB0F57EE3));
    assert(VerificationTest(hashFun!FastMurmurHash3_128_opt32, 128, 0xB3ECE62A));
    assert(VerificationTest(hashFun!FastMurmurHash3_128_opt64, 128, 0x6384BA69));
}
