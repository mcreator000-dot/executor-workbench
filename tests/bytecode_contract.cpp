// Contract snapshot for executor-workbench's vendored Luau Bytecode.h.
// Run from the repo root (C++11 or newer; no Luau library required):
//   c++ -std=c++11 -I luau_upstream/Common/include tests/bytecode_contract.cpp -o /tmp/bytecode-contract
//   /tmp/bytecode-contract
// Review format compatibility before updating any expected value.
#include <cstddef>
#include <cstdint>
#include <cstdio>

#include "Luau/BytecodeUtils.h"

#define EXPECT_VALUE(symbol, expected) \
    static_assert((symbol) == (expected), "Luau bytecode contract drift: " #symbol " expected " #expected)

EXPECT_VALUE(LBC_VERSION_MIN, 3);
EXPECT_VALUE(LBC_VERSION_MAX, 14);
EXPECT_VALUE(LBC_VERSION_TARGET, 14);
EXPECT_VALUE(LBC_VERSION_CLASSES, 100);
EXPECT_VALUE(LBC_TYPE_VERSION_MIN, 1);
EXPECT_VALUE(LBC_TYPE_VERSION_MAX, 3);
EXPECT_VALUE(LBC_TYPE_VERSION_TARGET, 3);

EXPECT_VALUE(LOP__COUNT, 95);

struct OpcodeContract
{
    LuauOpcode opcode;
    int words; // Header plus AUX, if any. NEWCLOSURE capture words are separate opcodes.
};

// One explicit row per opcode, in wire order. Let the compiler infer the array size so
// a missing row cannot become a zero-filled entry.
constexpr OpcodeContract opcodeContract[] = {
    {LOP_NOP, 1},
    {LOP_BREAK, 1},
    {LOP_LOADNIL, 1},
    {LOP_LOADB, 1},
    {LOP_LOADN, 1},
    {LOP_LOADK, 1},
    {LOP_MOVE, 1},
    {LOP_GETGLOBAL, 2},
    {LOP_SETGLOBAL, 2},
    {LOP_GETUPVAL, 1},
    {LOP_SETUPVAL, 1},
    {LOP_CLOSEUPVALS, 1},
    {LOP_GETIMPORT, 2},
    {LOP_GETTABLE, 1},
    {LOP_SETTABLE, 1},
    {LOP_GETTABLEKS, 2},
    {LOP_SETTABLEKS, 2},
    {LOP_GETTABLEN, 1},
    {LOP_SETTABLEN, 1},
    {LOP_NEWCLOSURE, 1},
    {LOP_NAMECALL, 2},
    {LOP_CALL, 1},
    {LOP_RETURN, 1},
    {LOP_JUMP, 1},
    {LOP_JUMPBACK, 1},
    {LOP_JUMPIF, 1},
    {LOP_JUMPIFNOT, 1},
    {LOP_JUMPIFEQ, 2},
    {LOP_JUMPIFLE, 2},
    {LOP_JUMPIFLT, 2},
    {LOP_JUMPIFNOTEQ, 2},
    {LOP_JUMPIFNOTLE, 2},
    {LOP_JUMPIFNOTLT, 2},
    {LOP_ADD, 1},
    {LOP_SUB, 1},
    {LOP_MUL, 1},
    {LOP_DIV, 1},
    {LOP_MOD, 1},
    {LOP_POW, 1},
    {LOP_ADDK, 1},
    {LOP_SUBK, 1},
    {LOP_MULK, 1},
    {LOP_DIVK, 1},
    {LOP_MODK, 1},
    {LOP_POWK, 1},
    {LOP_AND, 1},
    {LOP_OR, 1},
    {LOP_ANDK, 1},
    {LOP_ORK, 1},
    {LOP_CONCAT, 1},
    {LOP_NOT, 1},
    {LOP_MINUS, 1},
    {LOP_LENGTH, 1},
    {LOP_NEWTABLE, 2},
    {LOP_DUPTABLE, 1},
    {LOP_SETLIST, 2},
    {LOP_FORNPREP, 1},
    {LOP_FORNLOOP, 1},
    {LOP_FORGLOOP, 2},
    {LOP_FORGPREP_INEXT, 1},
    {LOP_FASTCALL3, 2},
    {LOP_FORGPREP_NEXT, 1},
    {LOP_NATIVECALL, 1},
    {LOP_GETVARARGS, 1},
    {LOP_DUPCLOSURE, 1},
    {LOP_PREPVARARGS, 1},
    {LOP_LOADKX, 2},
    {LOP_JUMPX, 1},
    {LOP_FASTCALL, 1},
    {LOP_COVERAGE, 1},
    {LOP_CAPTURE, 1},
    {LOP_SUBRK, 1},
    {LOP_DIVRK, 1},
    {LOP_FASTCALL1, 1},
    {LOP_FASTCALL2, 2},
    {LOP_FASTCALL2K, 2},
    {LOP_FORGPREP, 1},
    {LOP_JUMPXEQKNIL, 2},
    {LOP_JUMPXEQKB, 2},
    {LOP_JUMPXEQKN, 2},
    {LOP_JUMPXEQKS, 2},
    {LOP_IDIV, 1},
    {LOP_IDIVK, 1},
    {LOP_GETUDATAKS, 2},
    {LOP_SETUDATAKS, 2},
    {LOP_NAMECALLUDATA, 2},
    {LOP_NEWCLASSMEMBER, 2},
    {LOP_CALLFB, 2},
    {LOP_CMPPROTO, 2},
    {LOP_FASTPCALL, 1},
    {LOP_NEWCLASS, 2},
    {LOP_CONSTRUCT, 2},
    {LOP_FINCONSTRUCT, 1},
    {LOP_GETPRIVATEFIELD, 2},
    {LOP_SETPRIVATEFIELD, 2},
};

constexpr std::size_t opcodeRows = sizeof(opcodeContract) / sizeof(opcodeContract[0]);
static_assert(opcodeRows == LOP__COUNT, "Luau bytecode contract drift: missing or extra opcode rows");

constexpr bool opcodeRowsMatchWireOrder(std::size_t i)
{
    return i == opcodeRows ||
        (opcodeContract[i].opcode == int(i) && (opcodeContract[i].words == 1 || opcodeContract[i].words == 2) &&
            opcodeRowsMatchWireOrder(i + 1));
}
static_assert(opcodeRowsMatchWireOrder(0), "Luau bytecode contract drift: opcode order or invalid width");

#undef EXPECT_VALUE

int main()
{
    // getOpLength defaults to 1 for unlisted opcodes. Pin the expected widths independently
    // so that losing an AUX entry fails this check even when all opcode numbers stay the same.
    for (const OpcodeContract& row : opcodeContract)
    {
        int actual = Luau::getOpLength(row.opcode);
        if (actual != row.words)
        {
            std::fprintf(stderr, "Luau bytecode contract drift: opcode %d expected %d words, got %d\n",
                int(row.opcode), row.words, actual);
            return 1;
        }
    }

    std::printf("Luau bytecode contract OK: %d opcodes, bytecode %d..%d, type encoding %d..%d\n",
        LOP__COUNT, LBC_VERSION_MIN, LBC_VERSION_MAX, LBC_TYPE_VERSION_MIN, LBC_TYPE_VERSION_MAX);
}
