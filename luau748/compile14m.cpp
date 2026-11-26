#include <cstdio>
#include <cstdlib>
#include <string>
#include "Luau/Compiler.h"
#include "Luau/BytecodeBuilder.h"
#include "Luau/Bytecode.h"
#include "Luau/BytecodeUtils.h"

// Opcode multiplier is a hypothesis, not a measurement: "kitty uses 227" came from another
// executor's source, not from anything we observed in this client. Make it an argument so
// 1 (plain) and 227 can be compared instead of assumed.
static unsigned g_mult = 227;

struct RbxEncoder : Luau::BytecodeEncoder {
    void encode(uint32_t* data, size_t count) override {
        for (auto i = 0u; i < count;) {
            auto& op = *reinterpret_cast<uint8_t*>(data + i);
            i += Luau::getOpLength(LuauOpcode(op));
            op = (uint8_t)(op * g_mult);
        }
    }
};

int main(int argc, char** argv) {
    if (argc < 3) { printf("usage: compile14m <in.lua> <out.luac> [multiplier]\n"); return 1; }
    if (argc >= 4) g_mult = (unsigned)atoi(argv[3]);
    FILE* f = fopen(argv[1], "rb");
    if (!f) { printf("cannot open %s\n", argv[1]); return 2; }
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    std::string src(n, '\0'); fread(&src[0], 1, n, f); fclose(f);
    Luau::CompileOptions opts;
    opts.optimizationLevel = 1;
    opts.debugLevel = 1;
    static RbxEncoder enc;
    std::string bc = Luau::compile(src, opts, {}, g_mult == 1 ? nullptr : &enc);
    if (bc.empty() || bc[0] == '\0') { printf("compile failed: %s\n", bc.c_str()); return 3; }
    FILE* o = fopen(argv[2], "wb");
    if (!o) return 4;
    fwrite(bc.data(), 1, bc.size(), o); fclose(o);
    printf("wrote %zu bytes, multiplier=%u, first code bytes follow\n", bc.size(), g_mult);
    return 0;
}
