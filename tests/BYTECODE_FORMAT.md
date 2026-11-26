<!-- coderabbit-ai-generated:v1 -->

# Luau bytecode contract for the workbench

This describes plain `Luau::compile` output for our own host, pinned to
[`97b2f4bf9cd935bed666f3e643a3b749b4d22f38`](https://github.com/luau-lang/luau/commit/97b2f4bf9cd935bed666f3e643a3b749b4d22f38).
That compiler emits **LBC 14, type encoding 3** by default. The loader also reads older formats;
the compiler does not emit them on request. Experimental LBC 100, selected by the class flag,
is outside this contract. See [`Bytecode.h:556–583`](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/Common/include/Luau/Bytecode.h#L556-L583) and
[`BytecodeBuilder.cpp:1401–1422`](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/Bytecode/src/BytecodeBuilder.cpp#L1401-L1422).

## Outer layout, in byte order

`v` below means an unsigned variable length integer: seven low bits of value per byte, least
significant group first, high bit set if another byte follows. It is a 32-bit value for ordinary
counts and indices; cost and historical integer magnitude use a 64-bit value. Fixed-width values
are written from native bytes. For little-endian MSVC builds, read 32-bit words/integers and
IEEE 754 floats/doubles in little-endian order. There is no padding between serialized fields.
See [`BytecodeBuilder.cpp:42–69`](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/Bytecode/src/BytecodeBuilder.cpp#L42-L69) and [`lvmload.cpp:136–185`](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/VM/src/lvmload.cpp#L136-L185).

| Order | Field |
| --- | --- |
| 1 | `u8` LBC version. There is no magic prefix. Version zero means the remaining bytes are error text from compilation. |
| 2 | LBC ≥4 only: `u8` type encoding version (1–3). LBC 3 has no byte here. |
| 3 | String table: `v` count, then for each string `v` byte length followed by exactly that many bytes. No terminator. String references are `v`, 1-based, with 0 representing no string. |
| 4 | Type encoding 3 only: repeated `u8` userdata index (1-based), `v` string reference, terminated by a zero index byte. Even an empty mapping has the zero byte. |
| 5 | `v` proto count, then that many proto records. For LBC ≥12, each record starts with `v` payload byte length, excluding the length itself. |
| 6 | `v` zero-based main proto ID. Child and closure proto IDs also index this proto table from zero. |

Sources: [`Compiler.cpp:6308–6355`](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/Compiler/src/Compiler.cpp#L6308-L6355),
[`BytecodeBuilder.cpp:762–799, 1123–1140`](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/Bytecode/src/BytecodeBuilder.cpp#L762-L799) ([string writer](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/Bytecode/src/BytecodeBuilder.cpp#L1123-L1140)),
[`lvmload.cpp:414–495, 963–1010`](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/VM/src/lvmload.cpp#L414-L495) ([tables](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/VM/src/lvmload.cpp#L963-L1010)).

## One proto payload

| Order | Field |
| --- | --- |
| 1 | Four `u8`: max stack size, parameter count, upvalue count, is-vararg. |
| 2 | LBC ≥4: `u8` flags, `v` type payload length, then that many type bytes. A zero length means no type payload. |
| 3 | `v` code **word** count, then that many `u32` words, including AUX and CAPTURE words. |
| 4 | `v` constant count, then that many tagged constants. |
| 5 | `v` child count, then `v` global proto ID per child. `NEWCLOSURE.D` indexes this local child list. |
| 6 | `v` line defined, `v` debug name string reference. |
| 7 | `u8` line info present. If set: `u8` log2 span, one `u8` delta per code word, then `((wordCount - 1) >> log2span) + 1` signed `i32` baseline deltas. Both streams accumulate from zero (the byte stream wraps modulo 256). There is no on-disk alignment padding; the loader only aligns its in-memory array. |
| 8 | `u8` debug info present. If set: `v` local count and records (`v` name string reference, `v` start PC, `v` end PC, `u8` register), then `v` upvalue-name count and that many `v` name string references. |
| 9 | LBC ≥11: `v` feedback slot count, then `u8` kind and kind-specific `v` payload per slot. Kind 0 is the call target PC. Kind 1 carries a shape and is experimental (LBC 100). |
| 10 | LBC ≥12: `v64` cost only if `flags & LPF_INLINABLE` (bit 3) is set. |

Type encoding 1 stores a signature as `u8` function type tag, `u8` parameter count, then one type
byte per parameter. Encodings 2/3 store three `v` values (signature byte length, typed upvalue
count, typed local count), signature bytes, one type byte per upvalue, then records
`u8 type; u8 reg; v startPC; v (endPC - startPC)` per typed local. Encoding 3 uses the outer
userdata map to remap tagged type bytes.

Sources: [`BytecodeBuilder.cpp:801–851`](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/Bytecode/src/BytecodeBuilder.cpp#L801-L851),
[936–1010](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/Bytecode/src/BytecodeBuilder.cpp#L936-L1010), [1076–1120](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/Bytecode/src/BytecodeBuilder.cpp#L1076-L1120),
[`lvmload.cpp:244–282`](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/VM/src/lvmload.cpp#L244-L282), [497–590](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/VM/src/lvmload.cpp#L497-L590),
[818–938](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/VM/src/lvmload.cpp#L818-L938) and [`Bytecode.h:790–809`](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/Common/include/Luau/Bytecode.h#L790-L809).

## Constant payloads

Each row follows a single `u8` tag. Constant indices are zero-based within the current proto.

| Tag | Payload |
| --- | --- |
| 0 nil | None. |
| 1 boolean | `u8` 0 or 1. |
| 2 number | `f64`. |
| 3 string | `v` string reference. |
| 4 import | `u32` packed import: bits 31:30 are the component count (1–3), then up to three 10-bit constant indices at shifts 20, 10, 0. |
| 5 table | `v` key count, then `v` key constant index per entry. |
| 6 closure | `v` global proto ID. |
| 7 vector (LBC ≥5) | Four `f32` components, including W for a three-component build. |
| 8 table with constants (LBC ≥7) | `v` key count, then pairs of `v` key constant index and `i32` value constant index. A negative value index is the unfilled-entry sentinel. |
| 9 historical integer (introduced in LBC 8) | `u8` negative flag, then `v64` magnitude. The pinned emitter and loader no longer implement this tag. |
| 10 historical class shape (introduced in LBC 10) | `v` class-name constant index, `v` property count, `v` method count, then `v` constant indices for property names followed by method names. The pinned experimental v100 payload adds two private-member count bytes after the name and writes only public name indices. Do not apply the v100 reader to legacy class shapes. |
| 11 double vector (LBC ≥13) | Four `f64` components. |

Sources: [`Bytecode.h:568–583`](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/Common/include/Luau/Bytecode.h#L568-L583),
[`BytecodeBuilder.cpp:850–934`](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/Bytecode/src/BytecodeBuilder.cpp#L850-L934), [1013–1024](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/Bytecode/src/BytecodeBuilder.cpp#L1013-L1024),
[1142–1161](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/Bytecode/src/BytecodeBuilder.cpp#L1142-L1161), [`lvmload.cpp:601–776`](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/VM/src/lvmload.cpp#L601-L776).
Historical layouts: [Luau 0.720 integer writer:762–774](https://github.com/luau-lang/luau/blob/0c6cea0122242ed76528848cfe130e9820e7f122/Bytecode/src/BytecodeBuilder.cpp#L762-L774)
and [Luau 0.730 class writer:978–987](https://github.com/luau-lang/luau/blob/5bc7f4b23756f69f4669b419fa9034f117ccd6fe/Bytecode/src/BytecodeBuilder.cpp#L978-L987).
If supporting only the pinned compiler's output, reject the historical integer and class encodings
explicitly. A version in the 3–14 range is not sufficient evidence that the pinned VM handles all
historical constant payloads.

## Changes by LBC version

| LBC | Field or instruction change |
| --- | --- |
| 3 | Oldest accepted record layout above. `FORGPREP` and `JUMPXEQK*` replace older loop and constant-compare forms; `FORGLOOP` AUX encoding changes. |
| 4 | Outer type version, per-proto flags and type payload; `IDIV` and `IDIVK`. Type encodings 1/2 originate here. |
| 5 | Float vector constants, `SUBRK`/`DIVRK`; type encoding 3 adds userdata name mapping. |
| 6 | `FASTCALL3`; no new record fields. |
| 7 | Table-with-constants tag. |
| 8 | Historical integer tag. |
| 9 | Atom-based userdata field access opcodes. The pinned loader can rewrite field/namecall opcodes after reading the original words. |
| 10 | Historical class shape tag and `NEWCLASSMEMBER`. |
| 11 | Per-proto feedback vector and `CALLFB`/`CMPPROTO`. |
| 12 | Proto byte length and conditional cost. |
| 13 | Double vector tag. |
| 14 | `FASTPCALL`; no new record fields. |

Sources: [`Bytecode.h:40–65`](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/Common/include/Luau/Bytecode.h#L40-L65) and
[`lvmload.cpp:779–816`](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/VM/src/lvmload.cpp#L779-L816).

## Instruction walk and the silent failure

Read the low eight bits of each header word as the opcode. The remaining bits are `ABC`
(three unsigned bytes), `AD` (A byte and signed high 16 bits), or `E` (signed high 24 bits),
as defined for each opcode. An AUX word is interpreted by its preceding opcode. Jump offsets
and debug PCs count words. A structural decoder may group `NEWCLOSURE` with one following
`CAPTURE` word per child upvalue; a word walk can print those CAPTURE opcodes as separate
entries. See [`Bytecode.h:10–31`](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/Common/include/Luau/Bytecode.h#L10-L31), [171–174](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/Common/include/Luau/Bytecode.h#L171-L174),
[512–547](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/Common/include/Luau/Bytecode.h#L512-L547) and [`Compiler.cpp:1858–1872`](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/Compiler/src/Compiler.cpp#L1858-L1872).

The workbench repo has a contract test and vendored references; it has no standalone
disassembler implementation. The vendored builder's text dump advances by `getOpLength`.
That helper's **default is 1**, so a new two-word opcode omitted from its switch leaves the
cursor on AUX, which can look like a valid opcode and corrupt the remaining disassembly.
The formatter's default only executes `LUAU_ASSERT`; it can emit nothing in a build without
assertions. See [`BytecodeUtils.h:11–53`](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/Common/include/Luau/BytecodeUtils.h#L11-L53) and
[`BytecodeBuilder.cpp:2978–2981`](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/Bytecode/src/BytecodeBuilder.cpp#L2978-L2981), [3186–3195](https://github.com/luau-lang/luau/blob/97b2f4bf9cd935bed666f3e643a3b749b4d22f38/Bytecode/src/BytecodeBuilder.cpp#L3186-L3195).

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:558ec9ef26c8a26448264e1cdc0fe68ba20d9dc018626fe9efa889c4860174d1 -->

The test asserts that `LOP__COUNT == 95`, that an inferred-size table has exactly
`LOP__COUNT` rows, and that each row matches its wire index. A separate compile-time
check compares each width to a pinned list of opcodes with AUX words. Changing
`{LOP_MOVE, 1}` to `{LOP_MOVE, 2}` fails compilation. The executable also checks each
explicit width against Luau's non-`constexpr` `getOpLength`. Dropping an AUX case in
the vendored helper fails the executable even if the enum and test table are unchanged.

<!-- /coderabbit-ai-generated:v1 -->
When wiring this into a decoder, apply the same coverage assertion to the decoder's actual
metadata table. If it has a separate formatter switch, require exhaustive enum coverage
(for GCC, `-Werror=switch-enum`) or generate the dispatch from that table. At runtime,
reject an unsupported opcode or a width larger than the remaining code words before reading
operands. Debug-only assertions cannot enforce those checks in a release build.
