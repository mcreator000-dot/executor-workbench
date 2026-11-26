#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>
#include "lua.h"
#include "lualib.h"
#include "luacode.h"
#include <string>
#include "Luau/Compiler.h"
#include "Luau/ParseResult.h"
#include "Luau/Parser.h"
#include "Luau/Ast.h"

static int run_bytes(const char* label, const char* data, size_t size)
{
    lua_State* L = luaL_newstate();
    luaL_openlibs(L);
    const int before = lua_gettop(L);
    const int rc = luau_load(L, label, data, size, 0);
    const int after = lua_gettop(L);
    printf("[%s] luau_load rc=%d pushed=%d type=%s\n", label, rc, after - before,
           (rc == 0 && after > before) ? lua_typename(L, lua_type(L, -1)) : "n/a");
    fflush(stdout);
    if (rc != 0) {
        const char* e = lua_tostring(L, -1);
        printf("[%s] LOAD ERROR: %s\n", label, e ? e : "(null)");
        lua_close(L);
        return 1;
    }
    const int prc = lua_pcall(L, 0, 1, 0);
    if (prc == 0) printf("[%s] lua_pcall rc=0 result=%.0f\n", label, lua_tonumber(L, -1));
    else { const char* e = lua_tostring(L, -1); printf("[%s] RUN ERROR: %s\n", label, e ? e : "(null)"); }
    fflush(stdout);
    lua_close(L);
    return prc == 0 ? 0 : 1;
}


// Syntax gate: compile a SOURCE file and report parser diagnostics with line/column.
// Compiling is not executing - nothing in the file runs here.
static int check_source(const char* label, const std::string& src)
{
    // Luau::compile() swallows CompileError internally and still returns bytecode for a
    // recovered AST, so "compiled OK" is NOT a syntax check. Parse explicitly and read the
    // error list - that is the only honest gate.
    Luau::Allocator allocator;
    Luau::AstNameTable names(allocator);
    Luau::ParseOptions popts;
    Luau::ParseResult pr = Luau::Parser::parse(src.c_str(), src.size(), names, allocator, popts);
    if (!pr.errors.empty()) {
        int n = 0;
        for (const Luau::ParseError& pe : pr.errors) {
            const Luau::Location loc = pe.getLocation();
            printf("[%s] SYNTAX ERROR %u:%u: %s\n", label, (unsigned)loc.begin.line,
                   (unsigned)loc.begin.column, pe.getMessage().c_str());
            if (++n >= 20) break;
        }
        fflush(stdout);
        return 1;
    }
    Luau::CompileOptions opts;
    try {
        std::string bc = Luau::compile(src, opts);
        printf("[%s] OK parses; %zu bytes of bytecode\n", label, bc.size());
    } catch (std::exception& e) {
        printf("[%s] OK parses; bytecode failed: %s\n", label, e.what());
        return 1;
    }
    fflush(stdout);
    return 0;
}

int main(int argc, char** argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    if (argc >= 2 && strcmp(argv[1], "--control") == 0) {
        const char* src = "return 42";
        size_t outsize = 0;
        char* bc = luau_compile(src, strlen(src), nullptr, &outsize);
        if (!bc) { printf("[control] luau_compile returned null\n"); return 2; }
        printf("[control] compiled %zu bytes, header %02x %02x %02x\n", outsize,
               (unsigned char)bc[0], outsize > 1 ? (unsigned char)bc[1] : 0, outsize > 2 ? (unsigned char)bc[2] : 0);
        int r = run_bytes("control", bc, outsize);
        free(bc);
        return r;
    }
    if (argc >= 3 && strcmp(argv[1], "--check") == 0) {
        int rc2 = 0;
        for (int i = 2; i < argc; ++i) {
            FILE* f = fopen(argv[i], "rb");
            if (!f) { printf("[%s] cannot open\n", argv[i]); rc2 = 2; continue; }
            fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
            std::string src;
            if (n > 0) { src.resize((size_t)n); size_t got = fread(&src[0], 1, (size_t)n, f); src.resize(got); }
            fclose(f);
            rc2 |= check_source(argv[i], src);
        }
        return rc2;
    }
    int rc = 0;
    for (int i = 2; i < argc; ++i) {
        FILE* f = fopen(argv[i], "rb");
        if (!f) { printf("[%s] cannot open\n", argv[i]); rc = 2; continue; }
        fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
        std::vector<char> buf(n > 0 ? n : 0);
        if (n > 0) fread(buf.data(), 1, n, f);
        fclose(f);
        printf("[%s] %ld bytes, header %02x %02x %02x\n", argv[i], n,
               n > 0 ? (unsigned char)buf[0] : 0, n > 1 ? (unsigned char)buf[1] : 0, n > 2 ? (unsigned char)buf[2] : 0);
        fflush(stdout);
        rc |= run_bytes(argv[i], buf.data(), buf.size());
    }
    return rc;
}
