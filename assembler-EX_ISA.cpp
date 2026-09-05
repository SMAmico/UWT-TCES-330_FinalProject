

/*
    Simple two-pass assembler for the project's EX_ISA.

    Usage: assembler-EX_ISA <input.asm> <output.txt> [--mif] [--mif-out <output.mif>]
                             [--data-out <data.txt>] [--data-mif-out <data.mif>]

    This machine has split instruction/data memories: <output.txt>/<output.mif> hold the assembled
    instruction stream, while the data section is written to its own plaintext file (default
    <output>.data.txt, override with --data-out) and, with --mif, its own MIF (default
    <output>.data.mif, override with --data-mif-out).

    Assembly syntax (whitespace and commas separate tokens):

    - Registers: R0 .. R15 (case-insensitive) or numeric 0..15. R0 is fixed at zero, R14 is ASM_TMP, and R15 is PC.
      -- Assembly formatting instructions --
      - Use .text for instructions and instruction labels.
      - Use .data for data directives and data labels.
      - Labels end with ':' and may appear on their own line.
      - Tokens are separated by whitespace and/or commas.
      - Comments may start with ';', '//' or '#'.
    - Registers are R0..R15 (case-insensitive).
    - Control-flow labels (JMP/JLT and conditional pseudo-branch forms) must be .text labels.
      - Memory-address labels (STR/LDR label form) must be .data labels.

    .data directives (written to the separate data output/MIF described above):
      .word v1[, v2...]   writes one 16-bit word per value
      .space count        writes count zero words
      .long v1[, v2...]   writes 2 words per 32-bit value, most-significant word first
      .quad v1[, v2...]   writes 4 words per 64-bit value, most-significant word first
      .string "literal"   writes ceil((chars+1)/2) words, packing 2 chars/word (first char in the high
                          byte) plus a null terminator; backslash escapes (\n \t \r \\ \" \0) decode
                          to their real byte value before packing

        Debug metadata directives emitted by the 8cc backend are accepted and do not
        contribute to instruction or data addresses:
            .file number "filename"
            .loc file line [column]

    Instruction formats implemented :

      STR rA, rB/LABEL, soff (store RF[rA] -> D[RF[rB] + soff])
          -> 0001 raaa rbbb soff  offsets are signed 16-bit word displacements; larger values use ASM_TMP
      LDR rA, rB/LABEL, soff (load D[RF[rB] + soff] -> RF[rA])
          -> 0010 raaa rbbb soff  offsets are signed 16-bit word displacements; larger values use ASM_TMP

      COPY rSrc, rDest[, count] (copy count words from RF[rSrc] to RF[rDest])
          -> pseudo-instruction: expands to LDR/STR pairs using ASM_TMP; omitted count means one word
             count is a positive 16-bit value and source/destination registers are restored for long copies

      ADD rA, rB, rC (rA = rB + rC)
          -> 0011 raaa rbbb rccc
      ADDI rA, rB, imm/label (rA = rB + immediate)
          -> pseudo-instruction: MOVI ASM_TMP, immediate; ADD rA, rB, ASM_TMP
      SUB rA, rB, rC (rA = rB - rC)
          -> 0100 raaa rbbb rccc
      SUBI rA, rB, imm/label (rA = rB - immediate)
          -> pseudo-instruction: MOVI ASM_TMP, immediate; SUB rA, rB, ASM_TMP
      HLT                              
          -> 0101 0000 0000 0000

    MOVI rA, imm8_or_label (rA = rA | imm)
          -> 0110 raaa dddddddd     (ORs the immediate value into the selected register, using pseudoins for >8 bits)
             can load a label from either iram or dram.
      OR  rA, rB, rC   (rA = rB | rC)
          -> 0111 raaa rbbb rccc
      ORI rA, rB, imm/label (rA = rB | immediate)
          -> pseudo-instruction: MOVI ASM_TMP, immediate; OR rA, rB, ASM_TMP
      AND rA, rB, rC   (rA = rB & rC)
          -> 1000 raaa rbbb rccc
      ANDI rA, rB, imm/label (rA = rB & immediate)
          -> pseudo-instruction: MOVI ASM_TMP, immediate; AND rA, rB, ASM_TMP

      JMP offset/LABEL (PC = PC + soff12)
          -> 1001 bbbb bbbb bbbb  (signed 12-bit PC-relative offset)
      JMP rA (optional pseudo-form: PC = RF[rA])
          -> copies the register value into the PC register
      JNZ rA, rB, soff4 (PC = RF[rB] + soff4 if RF[rA] != 0)
          -> 1010 raaa rbbb bbbb
      JLT rA, rB, offset (PC = PC + offset if rA < rB)
          -> 1011 raaa rbbb bbbb    (4-bit signed offset relative to next instr)
      JZ rA, label (branch if rA == 0)
      JEQ rA, rB_or_imm, label (branch if rA == rB_or_imm)
      JNE rA, rB_or_imm, label (branch if rA != rB_or_imm)
      JLE rA, rB_or_imm, label (branch if signed rA <= rB_or_imm)
      JGT rA, rB_or_imm, label (branch if signed rA > rB_or_imm)
      JGE rA, rB_or_imm, label (branch if signed rA >= rB_or_imm)
          -> pseudo-instructions: CMP, SETcc, and JNZ via ASM_TMP; immediates are signed 16-bit values

      CMP rA, rB (capture Z, N, and V from signed rA - rB)
          -> 1110 raaa rbbb 0000
      SETLT rD (rD = 1 if the most recent CMP was signed less-than, else 0)
      SETEQ rD (rD = 1 if the most recent CMP was equal, else 0)
      SETNE rD (rD = 1 if the most recent CMP was not equal, else 0)
      SETLE rD (rD = 1 if the most recent CMP was signed less-than or equal, else 0)
      SETGT rD (rD = 1 if the most recent CMP was signed greater-than, else 0)
      SETGE rD (rD = 1 if the most recent CMP was signed greater-than or equal, else 0)
          -> 1110 rddd cccc 1111    (cc: 0=LT, 1=EQ, 2=NE, 3=LE, 4=GT, 5=GE)

      SHL rA, rB, shft (rA = rB << shft)
          -> 1100 raaa shft rccc     (shft is an unsigned 4-bit immediate)
      MULT rA, rB, rC  (rA = rB * rC)
          -> 1101 raaa rbbb rccc    
      MULTI rA, rB, imm/label (rA = rB * immediate)
          -> pseudo-instruction: MOVI ASM_TMP, immediate; MULT rA, rB, ASM_TMP
      SHR rA, rB, shft (rA = rB >> shft)
          -> 0000 raaa shft rccc

      NOP                         
          -> 1000 0000 0000 0000   (AND R0 with R0 into R0, effectively a NOP)
      MOV rA, rB       (rA = rB)
          -> 1000 raaa rbbb rccc    (AND RA with RA into RB, effectively moving) 
      XOR rA, rB, rC   (rA = rB ^ rC)
          -> pseudo-ins


    The assembler supports labels for PC-relative control flow and computes relative offsets
    as: offset = target_address - (current_address + 1).
    - JMP label uses a signed 12-bit offset (-2048..+2047).
    - JLT label uses a signed 4-bit offset (-8..+7).
*/

//DEFINES: aliases for all instructions in the ISA
#define ins_shr 0x0
#define ins_str 0x1
#define ins_ldr 0x2
#define ins_add 0x3
#define ins_sub 0x4
#define ins_hlt 0x5
#define ins_movi 0x6
#define ins_or 0x7
#define ins_and 0x8
#define ins_jmp 0x9
#define ins_jnz 0xA
#define ins_jlt 0xB
#define ins_shl 0xC
#define ins_mult 0xD
#define ins_cmp_set 0xE

//REGISTER DEFINES: aliases for special registers in the ISA
//zero reg is always left at 0
#define reg_zero 0
//program counter indicates the address in the instruction memory to execute next
#define PC 15
//temporary register for assembly to machine code translation
#define ASM_TMP 14

#include <algorithm>
#include <cctype>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <unordered_map>
#include <vector>
using namespace std;

// The FSM encodes ALU operations as source A, source B, destination.
static uint16_t encode_alu(int opcode, int source_a, int source_b, int destination) {
    return (uint16_t)((opcode << 12) | (source_a << 8) | (source_b << 4) | destination);
}

//function cleans each line so its just the instruction
static inline string trim(const string &s) {

    size_t a = s.find_first_not_of(" \t\r\n");
    if (a==string::npos) return "";
    size_t b = s.find_last_not_of(" \t\r\n");
    return s.substr(a, b-a+1);
}

//takes in string, returns a vector of string chunks (tokens)
static inline vector<string> split_tokens(const string &line) {
    //create vector
    vector<string> toks;
    string cur;
    //for each 
    for (size_t i=0;i<line.size();) {

        if ( isspace((unsigned char)line[i] ) || line[i] == ',') {
            i++;
            continue;
        }

        if (line[i] == '/' && i+1<line.size() && line[i+1]=='/') break;

        //break at line end or comment
        if (line[i] == ';' || line[i]=='#') break;

        // token: read until whitespace or comma
        size_t j = i;

        //splits each line into tokens fenceposted by commas
        while (j < line.size() && !isspace((unsigned char)line[j]) && line[j] != ',') j++;

        //adds the token to the vector based on its bounds
        toks.push_back(line.substr(i, j-i));
        i = j;
    }
    //return the tokenized string
    return toks;

}



//converts RN register terminology to direct register address
//input: token equivalent of register
//output: register value
int parse_reg(const string &token) {
    //takes register
    string s = token;
    for (auto &c: s) c = toupper((unsigned char)c);
    //reads until R then converts following integer to hex
    if (s.size() > 0 && s[0] == 'R') {
        string num = s.substr(1);
        int v = stoi(num);
        if (v < 0 || v > 15) throw runtime_error("register out of range: "+token);
        return v;
    }
    // as an alternate input, allow raw numbers 0-15 too.
    {
        int v = stoi(s);
        if (v < 0 || v > 15) throw runtime_error("register out of range: "+token);
        return v;
    }
}

//converts number strings to integers
int parse_number(const string &token) {
    string s = token;
    //converts hex inputs (ie 0x4FD) to integer properly
    if (s.size() > 1 && s[0]=='0' && (s[1]=='x' || s[1]=='X')) {
        return stoi(s,nullptr,16);
    }
    //catch negative values too
    if (s.size() > 1 && s[0] == '-') {
        return stoi(s,nullptr,0);
    }
    // decimal by default
    return stoi(s,nullptr,0);
}

//parses a literal into a 64-bit value so .long/.quad can validate ranges beyond parse_number's 32-bit stoi
static long long parse_number64(const string &token) {
    string s = token;
    if (s.size() > 1 && s[0]=='0' && (s[1]=='x' || s[1]=='X')) {
        return (long long)stoull(s, nullptr, 16);
    }
    if (!s.empty() && s[0] == '-') {
        return stoll(s, nullptr, 0);
    }
    return (long long)stoull(s, nullptr, 0);
}

//checks if a signed offset fits within a 4-bit length
static int parse_offset4(const string &token) {
    int value = parse_number(token);
    if (value < -8 || value > 7) throw runtime_error("offset out of range (-8..7)");
    return value;
}

static int parse_memory_offset(const string &token) {
    int value = parse_number(token);
    if (value < -32768 || value > 32767)
        throw runtime_error("memory offset out of range (-32768..32767)");
    return value;
}

static int parse_copy_count(const string &token) {
    int count = parse_number(token);
    if (count < 1 || count > 65535)
        throw runtime_error("COPY count out of range (1..65535)");
    return count;
}

//loads a 16-bit immediate value into a register, using a temporary register if greater than 8 bits.
static void emit_load_imm(vector<uint16_t> &words,
                          int reg,
                          int value,
                          int &addr,
                          vector<string> *comments = nullptr,
                          const string &comment = "") {
    if (value < 0 || value > 65535) throw runtime_error("immediate out of range");
    if (value > 255) {
        int upper = (value >> 8) & 0xFF;
        int lower = value & 0xFF;
        words.push_back((ins_movi<<12) | (ASM_TMP << 8) | (upper & 0xFF));
        if (comments) comments->push_back(comment);
        words.push_back((ins_shl<<12) | (ASM_TMP << 8) | (0x8 << 4) | 0x1);
        if (comments) comments->push_back(comment);
        words.push_back((ins_movi<<12) | (ASM_TMP << 8) | (lower & 0xFF));
        if (comments) comments->push_back(comment);
        words.push_back((ins_or<<12) | (reg << 8) | (ASM_TMP << 4) | reg);
        if (comments) comments->push_back(comment);
        addr += 4;
    } else {
        words.push_back((ins_movi<<12) | (reg << 8) | (value & 0xFF));
        if (comments) comments->push_back(comment);
        addr++;
    }
}

static int immediate_word_count(int value) {
    return value >= 0 && value <= 255 ? 1 : 4;
}

static int memory_access_word_count(int offset) {
    if (offset >= -8 && offset <= 7)
        return 1;
    return immediate_word_count(offset < 0 ? -offset : offset) + 2;
}

static void emit_memory_access(vector<uint16_t> &words,
                               vector<string> *comments,
                               const string &comment,
                               int opcode,
                               int data_reg,
                               int base_reg,
                               int offset,
                               int &addr) {
    if (offset >= -8 && offset <= 7) {
        words.push_back((opcode << 12) | (data_reg << 8) | (base_reg << 4) | (offset & 0xF));
        if (comments) comments->push_back(comment);
        addr++;
        return;
    }

    if (opcode == ins_str && data_reg == ASM_TMP)
        throw runtime_error("large-offset STR cannot use R14 as the source register");

    int magnitude = offset < 0 ? -offset : offset;
    emit_load_imm(words, ASM_TMP, magnitude, addr, comments, comment);
    if (offset < 0)
        words.push_back(encode_alu(ins_sub, base_reg, ASM_TMP, ASM_TMP));
    else
        words.push_back(encode_alu(ins_add, base_reg, ASM_TMP, ASM_TMP));
    if (comments) comments->push_back(comment);
    addr++;
    words.push_back((opcode << 12) | (data_reg << 8) | (ASM_TMP << 4));
    if (comments) comments->push_back(comment);
    addr++;
}

static int copy_word_count(int count) {
    int chunks = (count + 15) / 16;
    int words = count * 2;
    if (chunks > 1) {
        words += (chunks - 1) * 4;
        words += (count > 255 ? 5 : 2) * 2;
    }
    return words;
}

static void emit_copy(vector<uint16_t> &words,
                      vector<string> *comments,
                      const string &comment,
                      int source,
                      int destination,
                      int count,
                      int &addr) {
    int copied = 0;
    while (copied < count) {
        int chunk = min(16, count - copied);
        for (int offset = 0; offset < chunk; ++offset) {
            words.push_back((ins_ldr<<12) | (ASM_TMP<<8) | (source<<4) | offset);
            if (comments) comments->push_back(comment);
            words.push_back((ins_str<<12) | (ASM_TMP<<8) | (destination<<4) | offset);
            if (comments) comments->push_back(comment);
            addr += 2;
        }
        copied += chunk;
        if (copied < count) {
            emit_load_imm(words, ASM_TMP, 16, addr, comments, comment);
            words.push_back(encode_alu(ins_add, source, ASM_TMP, source));
            if (comments) comments->push_back(comment);
            addr++;
            emit_load_imm(words, ASM_TMP, 16, addr, comments, comment);
            words.push_back(encode_alu(ins_add, destination, ASM_TMP, destination));
            if (comments) comments->push_back(comment);
            addr++;
        }
    }
    if (count > 16) {
        emit_load_imm(words, ASM_TMP, count, addr, comments, comment);
        words.push_back(encode_alu(ins_sub, source, ASM_TMP, source));
        if (comments) comments->push_back(comment);
        addr++;
        emit_load_imm(words, ASM_TMP, count, addr, comments, comment);
        words.push_back(encode_alu(ins_sub, destination, ASM_TMP, destination));
        if (comments) comments->push_back(comment);
        addr++;
    }
}

//converts a string to uppercase
static inline string upper_copy(string s) {
    for (auto &c : s) c = toupper((unsigned char)c);
    return s;
}

//decodes a quoted .string literal's backslash escapes into raw character codes
static vector<uint16_t> decode_string_literal(const string &content) {
    vector<uint16_t> chars;
    for (size_t k = 0; k < content.size(); ++k) {
        if (content[k] == '\\' && k + 1 < content.size()) {
            char esc = content[++k];
            switch (esc) {
                case 'n': chars.push_back('\n'); break;
                case 't': chars.push_back('\t'); break;
                case 'r': chars.push_back('\r'); break;
                case '0': chars.push_back('\0'); break;
                case '\\': chars.push_back('\\'); break;
                case '"': chars.push_back('"'); break;
                default: chars.push_back((unsigned char)esc); break;
            }
        } else {
            chars.push_back((unsigned char)content[k]);
        }
    }
    return chars;
}

//tries to lookup a label in a table, returns true if found and sets value, false otherwise
static bool try_lookup_label(const unordered_map<string,int> &table, const string &name, int &value) {
    auto it = table.find(name);
    if (it == table.end()) return false;
    value = it->second;
    return true;
}

//replace or append a file extension (including the leading dot)
static string replace_extension(const string &path, const string &new_ext) {
    size_t slash = path.find_last_of("/\\");
    size_t dot = path.find_last_of('.');
    if (dot != string::npos && (slash == string::npos || dot > slash)) {
        return path.substr(0, dot) + new_ext;
    }
    return path + new_ext;
}

//write Quartus-style MIF output for ROM/RAM initialization
static void write_mif_file(const string &path,
                           const vector<uint16_t> &words,
                           int depth,
                           const vector<string> &comments = {}) {
    if (depth <= 0) throw runtime_error("MIF depth must be positive");
    if ((int)words.size() > depth) throw runtime_error("program is larger than MIF depth");
    if (!comments.empty() && comments.size() != words.size()) {
        throw runtime_error("internal error: MIF comment count does not match word count");
    }

    ofstream ofs(path);
    if (!ofs) throw runtime_error("Cannot open MIF output " + path);

    ofs << "WIDTH=16;\n";
    ofs << "DEPTH=" << dec << depth << ";\n\n";
    ofs << "ADDRESS_RADIX=HEX;\n";
    ofs << "DATA_RADIX=HEX;\n\n";
    ofs << "CONTENT BEGIN\n";

    ofs << uppercase << hex << setfill('0');
    for (size_t i = 0; i < words.size(); ++i) {
        ofs << "    " << setw(2) << i << " : " << setw(4) << (unsigned int)words[i] << ";";
        if (!comments.empty() && !comments[i].empty()) {
            ofs << " -- " << comments[i];
        }
        ofs << "\n";
    }

    if ((int)words.size() < depth) {
        ofs << "\n    [" << setw(2) << words.size() << ".." << setw(4) << (unsigned int)(depth - 1)
            << "] : 0000;\n";
    }

    ofs << "END;\n";
}

//resolve a label to an address, checking both instruction and data label tables
static int resolve_any_label(const unordered_map<string,int> &instr_labels,
                             const unordered_map<string,int> &data_labels,
                             const string &token) {
    int iaddr = 0;
    int daddr = 0;
    bool has_i = try_lookup_label(instr_labels, token, iaddr);
    bool has_d = try_lookup_label(data_labels, token, daddr);
    if (has_i && has_d) throw runtime_error("ambiguous label found in both instruction/data spaces: " + token);
    if (has_i) return iaddr;
    if (has_d) return daddr;
    throw runtime_error("unknown label: " + token);
}

//estimates the amount of instructions generated per pseudoinstruction, to keep label addresses accurate.
static int estimate_instr_words(const vector<string> &tokens,
                                const unordered_map<string,int> &instr_labels,
                                const unordered_map<string,int> &data_labels) {
    if (tokens.empty()) return 0;
    string op = upper_copy(tokens[0]);
    if (op == "COPY" && tokens.size() >= 3) {
        if (tokens.size() == 3)
            return 2;
        if (tokens.size() == 4) {
            int count = 0;
            try {
                count = parse_copy_count(tokens[3]);
            } catch (...) {
                return 1;
            }
            return copy_word_count(count);
        }
    }
    if (op == "JZ" && tokens.size() >= 3)
        return 3;
    if ((op == "JEQ" || op == "JNE" || op == "JLE" ||
         op == "JGT" || op == "JGE") && tokens.size() >= 4) {
        try {
            int value = parse_number(tokens[2]);
            return (value >= 0 && value <= 255) ? 4 : 7;
        } catch (...) {
            return 3;
        }
    }
    if ((op == "ADDI" || op == "SUBI" || op == "ORI" || op == "ANDI" || op == "MULTI") && tokens.size() >= 4) {
        int value = 0;
        try {
            value = parse_number(tokens[3]);
        } catch (...) {
            if (!try_lookup_label(instr_labels, tokens[3], value) &&
                !try_lookup_label(data_labels, tokens[3], value)) {
                return 1;
            }
        }
        return (value > 255) ? 5 : 2;
    }
    if (op == "XOR") return 5;
    if (op == "MOVI" && tokens.size() >= 3) {
        int value = 0;
        bool known = false;
        try {
            value = parse_number(tokens[2]);
            known = true;
        } catch (...) {
            int addr = 0;
            if (try_lookup_label(instr_labels, tokens[2], addr) || try_lookup_label(data_labels, tokens[2], addr)) {
                value = addr;
                known = true;
            }
        }
        if (known && value > 255) return 4;
        return 1;
    }
    if ((op == "STR" || op == "LDR" || op == "LOAD") && tokens.size() >= 3) {
        int addr = 0;
        if (try_lookup_label(data_labels, tokens[2], addr)) {
            if (tokens.size() < 4)
                return (addr > 255) ? 5 : 2;
            try {
                int offset = parse_memory_offset(tokens[3]);
                int target = addr + offset;
                return (target >= 0 && target <= 255) ? 2 : 5;
            } catch (...) {
                return 1;
            }
        }
        if (tokens.size() >= 4) {
            try {
                return memory_access_word_count(parse_memory_offset(tokens[3]));
            } catch (...) {
                return 1;
            }
        }
    }
    return 1;
}

//main loop
int main(int argc, char** argv) {
    //print input
    if (argc<3) {
        cerr<<"Usage: "<<argv[0]<<" <input.asm> <output.txt> [--mif] [--mif-out <output.mif>]\n";
        return 1;
    }
    //the paths for our input and output files
    string inpath = argv[1];
    string outpath = argv[2];
    bool emit_mif = false;
    string mif_outpath = replace_extension(outpath, ".mif");
    //data memory is separate hardware from instruction memory, so it gets its own output files
    string data_outpath = replace_extension(outpath, ".data.txt");
    string data_mif_outpath = replace_extension(outpath, ".data.mif");

    for (int i = 3; i < argc; ++i) {
        string arg = argv[i];
        if (arg == "--mif") {
            emit_mif = true;
        } else if (arg == "--mif-out") {
            if (i + 1 >= argc) {
                cerr<<"Missing value for --mif-out\n";
                return 1;
            }
            emit_mif = true;
            mif_outpath = argv[++i];
        } else if (arg == "--data-out") {
            if (i + 1 >= argc) {
                cerr<<"Missing value for --data-out\n";
                return 1;
            }
            data_outpath = argv[++i];
        } else if (arg == "--data-mif-out") {
            if (i + 1 >= argc) {
                cerr<<"Missing value for --data-mif-out\n";
                return 1;
            }
            emit_mif = true;
            data_mif_outpath = argv[++i];
        } else {
            cerr<<"Unknown argument: "<<arg<<"\n";
            cerr<<"Usage: "<<argv[0]<<" <input.asm> <output.txt> [--mif] [--mif-out <output.mif>]"
                <<" [--data-out <data.txt>] [--data-mif-out <data.mif>]\n";
            return 1;
        }
    }

    //the raw lines as a vector
    vector<string> lines;

    {
        ifstream ifs(inpath);
        if (!ifs) { cerr<<"Cannot open "<<inpath<<"\n"; return 1; }
        string raw;
        while (getline(ifs, raw)) lines.push_back(raw);
    }

    // First pass: collect labels and normalize lines
    // traverse the full length of the file twice to properly
    // capture jumps to labels, etc

    unordered_map<string,int> instr_labels;
    unordered_map<string,int> data_labels;

    //our indicators of the section, line and current address.
    vector<string> norm_lines;
    enum class Section { Text, Data };
    //files always start with the text segment
    Section section = Section::Text;
    //our 'base address'. this can be changed to re-center code to any memory location.
    int instr_addr = 0;
    int data_addr = 0;
    //the actual contents of data memory, built directly since .data values have no forward references
    vector<uint16_t> data_words;
    vector<string> data_comments;

    for (size_t i=0;i<lines.size();++i) {

        // fetch X line from the vector
        string l = lines[i];
        // mark out the locations of the important characters
        // in a line, ( #, //, ; ). 
        size_t cpos = l.find("//");
        size_t cpos2 = l.find(';');

        // if a semicolon is present and before a comment, set the semicolon as the EOL
        if (cpos2!=string::npos && (cpos==string::npos || cpos2<cpos)) cpos = cpos2;

        size_t cpos3 = l.find('#');

        // if a hashtag is present and before a comment, set the hashtag as the EOL
        if (cpos3!=string::npos && (cpos==string::npos || cpos3<cpos)) cpos = cpos3;

        //if the comment indicator exists, trim line length to remove it
        if (cpos!=string::npos) l = l.substr(0,cpos);

        //pull off spaces
        l = trim(l);
        //ignore empty lines
        if (l.empty()) continue;
        //allow one or more labels before content: label1: label2: instr
        while (true) {
            //find the first colon, if none, break
            size_t colon = l.find(':');
            if (colon==string::npos) break;
            //extract the label name, and trim it
            string lab = trim(l.substr(0,colon));
            //if the label is empty, error
            if (lab.empty()) { cerr<<"Empty label on line "<<(i+1)<<"\n"; return 1; }
            //if we're in the text section
            if (section == Section::Text) {
                //check for uniqueness, then add to the instruction label map
                if (instr_labels.find(lab)!=instr_labels.end()) {
                    cerr<<"Duplicate instruction label "<<lab<<"\n";
                    return 1;
                }
                instr_labels[lab] = instr_addr;
            } else {
                //otherwise, check for uniqueness and add to the data label map
                if (data_labels.find(lab)!=data_labels.end()) {
                    cerr<<"Duplicate data label "<<lab<<"\n";
                    return 1;
                }
                data_labels[lab] = data_addr;
            }
            //trim to remove the label and colon, then move on.
            l = trim(l.substr(colon+1));
            if (l.empty()) break;
        }

        //if there aren't any more tokens in the line, continue on
        if (l.empty()) continue;
        auto tokens = split_tokens(l);
        if (tokens.empty()) continue;
        string op = upper_copy(tokens[0]);

        //now, check if we're in a text or data section, and change accordingly.
        if (op == ".TEXT") {
            section = Section::Text;
            continue;
        }
        if (op == ".DATA") {
            section = Section::Data;
            continue;
        }

        // Debug metadata does not occupy either memory space.  Accept it before
        // section-specific directive handling so it is ignored in both sections.
        if (op == ".FILE") {
            if (tokens.size() < 3) {
                cerr<<".file requires a file number and filename on line "<<(i+1)<<"\n";
                return 1;
            }
            continue;
        }
        if (op == ".LOC") {
            if (tokens.size() < 3) {
                cerr<<".loc requires a file number and line on line "<<(i+1)<<"\n";
                return 1;
            }
            continue;
        }

        //if we're in data, only allow .word, .space, .string, .long, and .quad.
        if (section == Section::Data) {
            if (op == ".WORD") {
                //if .word, there must be at least one value to put in
                if (tokens.size() < 2) { cerr<<".word requires at least one value on line "<<(i+1)<<"\n"; return 1; }
                for (size_t k = 1; k < tokens.size(); ++k) {
                    int v = 0;
                    try { v = parse_number(tokens[k]); }
                    catch (...) { cerr<<"Invalid .word value '"<<tokens[k]<<"' on line "<<(i+1)<<"\n"; return 1; }
                    data_words.push_back((uint16_t)(v & 0xFFFF));
                    data_comments.push_back(l);
                    data_addr++;
                }
                continue;
            }
            if (op == ".SPACE") {
                //if space, enforce its space argument is the only thing present
                if (tokens.size() != 2) { cerr<<".space requires exactly one size argument on line "<<(i+1)<<"\n"; return 1; }
                int count = 0;
                try { count = parse_number(tokens[1]); }
                catch (...) { cerr<<"Invalid .space size on line "<<(i+1)<<"\n"; return 1; }
                if (count < 0) { cerr<<".space size must be >= 0 on line "<<(i+1)<<"\n"; return 1; }
                for (int k = 0; k < count; ++k) {
                    data_words.push_back(0);
                    data_comments.push_back(l);
                }
                data_addr += count;
                continue;
            }
            if (op == ".LONG") {
                //32-bit value occupies 2 words on this 16-bit-word machine, most-significant word first
                if (tokens.size() < 2) { cerr<<".long requires at least one value on line "<<(i+1)<<"\n"; return 1; }
                for (size_t k = 1; k < tokens.size(); ++k) {
                    long long v = 0;
                    try { v = parse_number64(tokens[k]); }
                    catch (...) { cerr<<"Invalid .long value '"<<tokens[k]<<"' on line "<<(i+1)<<"\n"; return 1; }
                    if (v < -2147483648LL || v > 4294967295LL) { cerr<<".long value out of range: "<<tokens[k]<<"\n"; return 1; }
                    uint32_t uv = (uint32_t)(uint64_t)v;
                    data_words.push_back((uint16_t)((uv >> 16) & 0xFFFF));
                    data_comments.push_back(l);
                    data_words.push_back((uint16_t)(uv & 0xFFFF));
                    data_comments.push_back(l);
                    data_addr += 2;
                }
                continue;
            }
            if (op == ".QUAD") {
                //64-bit value occupies 4 words on this 16-bit-word machine, most-significant word first
                if (tokens.size() < 2) { cerr<<".quad requires at least one value on line "<<(i+1)<<"\n"; return 1; }
                for (size_t k = 1; k < tokens.size(); ++k) {
                    long long v = 0;
                    try { v = parse_number64(tokens[k]); }
                    catch (...) { cerr<<"Invalid .quad value '"<<tokens[k]<<"' on line "<<(i+1)<<"\n"; return 1; }
                    uint64_t uv = (uint64_t)v;
                    data_words.push_back((uint16_t)((uv >> 48) & 0xFFFF));
                    data_comments.push_back(l);
                    data_words.push_back((uint16_t)((uv >> 32) & 0xFFFF));
                    data_comments.push_back(l);
                    data_words.push_back((uint16_t)((uv >> 16) & 0xFFFF));
                    data_comments.push_back(l);
                    data_words.push_back((uint16_t)(uv & 0xFFFF));
                    data_comments.push_back(l);
                    data_addr += 4;
                }
                continue;
            }
            if (op == ".STRING") {
                //quoted literal may contain spaces/commas, so pull it from the raw line rather than tokens
                size_t q1 = l.find('"');
                size_t q2 = (q1 != string::npos) ? l.find('"', q1 + 1) : string::npos;
                if (q1 == string::npos || q2 == string::npos || q2 <= q1) {
                    cerr<<".string requires a quoted string on line "<<(i+1)<<"\n"; return 1;
                }
                string content = l.substr(q1 + 1, q2 - q1 - 1);
                vector<uint16_t> chars = decode_string_literal(content);
                chars.push_back(0); // implicit null terminator
                for (size_t k = 0; k < chars.size(); k += 2) {
                    uint16_t hi = chars[k] & 0xFF;
                    uint16_t lo = (k + 1 < chars.size()) ? (chars[k+1] & 0xFF) : 0;
                    data_words.push_back((uint16_t)((hi << 8) | lo));
                    data_comments.push_back(l);
                    data_addr++;
                }
                continue;
            }
            cerr<<"Only .word, .space, .string, .long, and .quad are allowed in .data (line "<<(i+1)<<")\n";
            return 1;
        }

        //finally, add the lines to the lines vector, 
        norm_lines.push_back(l);
        //and add the estimated word count to our address ticker.
        instr_addr += estimate_instr_words(tokens, instr_labels, data_labels);
    }

    /*
        now that our labels for both data and instruction memory have been 
        converted into addresses, we can parse the instructions themselves to hex machine code. 
    */

    // Second pass: assemble
    vector<uint16_t> words;
    vector<string> word_comments;
    int addr = 0;
    for (auto &rawline: norm_lines) {
        string line = rawline;
        auto push_word = [&](uint16_t w) {
            words.push_back(w);
            word_comments.push_back(rawline);
        };
        auto tokens = split_tokens(line);
        if (tokens.empty()) {
            addr++;
            continue;
        }
        string op = tokens[0];
        for (auto &c: op) c = toupper((unsigned char)c);
        uint16_t instr = 0;

        try {

            //NOP: no operation
            if (op=="NOP") {

                instr = 0x8000;

            } else if (op=="COPY") {

                if (tokens.size() < 3 || tokens.size() > 4)
                    throw runtime_error("COPY expects SOURCE,DEST[,COUNT]");
                int source = parse_reg(tokens[1]);
                int destination = parse_reg(tokens[2]);
                int count = tokens.size() == 4 ? parse_copy_count(tokens[3]) : 1;
                if (source == ASM_TMP || destination == ASM_TMP)
                    throw runtime_error("COPY cannot use R14 as a source or destination address register");
    
                emit_copy(words, &word_comments, rawline, source, destination, count, addr);
                continue;

            } else if (op=="JZ" || op=="JEQ" || op=="JNE" || op=="JLE" ||
                       op=="JGT" || op=="JGE") {

                bool is_jz = op == "JZ";
                if ((is_jz && tokens.size()!=3) || (!is_jz && tokens.size()!=4))
                    throw runtime_error(op + (is_jz ? " expects REGISTER,LABEL" : " expects LEFT,RIGHT_OR_IMMEDIATE,LABEL"));

                int left = parse_reg(tokens[1]);
                int prefix_words = 2;
                int condition = 1;
                if (is_jz) {
                    push_word((ins_cmp_set<<12) | (left<<8) | (reg_zero<<4));
                } else {
                    int right = 0;
                    try {
                        right = parse_reg(tokens[2]);
                    } catch (...) {
                        int value = parse_number(tokens[2]);
                        if (value < -32768 || value > 65535)
                            throw runtime_error("comparison immediate out of range (-32768..65535)");
                        emit_load_imm(words, ASM_TMP, value & 0xFFFF, addr, &word_comments, rawline);
                        prefix_words += (value >= 0 && value <= 255) ? 1 : 4;
                        right = ASM_TMP;
                    }
                    push_word((ins_cmp_set<<12) | (left<<8) | (right<<4));
                    if (op=="JEQ") condition = 1;
                    else if (op=="JNE") condition = 2;
                    else if (op=="JLE") condition = 3;
                    else if (op=="JGT") condition = 4;
                    else condition = 5;
                }

                push_word((ins_cmp_set<<12) | (ASM_TMP<<8) | (condition<<4) | 0xF);
                const string &label = tokens[is_jz ? 2 : 3];
                if (instr_labels.find(label) == instr_labels.end())
                    throw runtime_error("instruction label required for " + op);
                int branch_addr = addr + prefix_words;
                int offset = instr_labels[label] - (branch_addr + 1);
                if (offset < -8 || offset > 7)
                    throw runtime_error(op + " target out of JNZ range (-8..7)");
                push_word((ins_jnz<<12) | (ASM_TMP<<8) | (PC<<4) | (offset & 0xF));
                addr += prefix_words + 1;
                continue;

            //STR: store register through variable addressing
            } else if (op=="STR") {

                if (tokens.size()<3) throw runtime_error("STR expects [Ra, Rb, offset] or [Ra, Rb]");

                int r = parse_reg(tokens[1]);
                int base_reg = ASM_TMP;
                int soff = 0;
                bool relative = false;
                bool use_label = false;
                int label_addr = 0;
                
                //if there are 3 tokens, 
                if (tokens.size()==3) {
                    //set the address register to the last token
                    string arg = tokens[2];
                    //if we find a label, mark the flag accordingly
                    if (data_labels.find(arg)!=data_labels.end()) {
                        use_label = true;
                        label_addr = data_labels[arg];
                    } else if (instr_labels.find(arg)!=instr_labels.end()) {
                        throw runtime_error("instruction label used where data label is required: " + arg);
                    } else {
                        //and parse it as a register
                        base_reg = parse_reg(arg);
                    }
                
                //if there are 4 tokens,
                } else if (tokens.size()>=4) {
                    //we must be using the Ra, Rb, offset format
                    relative = true;
                    //set the base register properly
                    string arg = tokens[2];
                    if (data_labels.find(arg)!=data_labels.end()) {
                        use_label = true;
                        label_addr = data_labels[arg];
                    } else if (instr_labels.find(arg)!=instr_labels.end()) {
                        throw runtime_error("instruction label used where data label is required: " + arg);
                    } else {
                        base_reg = parse_reg(arg);
                    }
                    //ensure the offset is a signed value within range.
                    soff = parse_memory_offset(tokens[3]);
                }

                //if we're asking for a relative address (ie, an offset relative to a label),
                if (relative && use_label) {
                    //we load the label and add the offset, then load
                    emit_load_imm(words, ASM_TMP, label_addr + soff, addr, &word_comments, rawline);
                    instr = (ins_str<<12) | (r<<8) | (ASM_TMP<<4) | (0x0);
                //if we're asking for an address with an offset
                } else if (relative) {
                    if (soff < -8 || soff > 7) {
                        emit_memory_access(words, &word_comments, rawline,
                                           ins_str, r, base_reg, soff, addr);
                        continue;
                    }
                    instr = (ins_str<<12) | (r<<8) | (base_reg<<4) | (soff & 0xF);
                //if we're asking for a label with no offset
                } else if (use_label) {
                    //we load the label into temp, then store
                    emit_load_imm(words, ASM_TMP, label_addr, addr, &word_comments, rawline);
                    addr++;
                    instr = (ins_str<<12) | (r<<8) | (ASM_TMP<<4) | (0x0);
                } else {
                    //otherwise, we just emit the STR instruction using the base register
                    instr = (ins_str<<12) | (r<<8) | (base_reg<<4) | (0x0);
                }

            //LDR: load register through variable addressing
            } else if (op=="LDR" || op=="LOAD") {

                if (tokens.size()<3) throw runtime_error("LDR expects [Ra, Rb, offset] or [Ra, Rb]");

                int r = parse_reg(tokens[1]);
                int base_reg = ASM_TMP;
                int soff = 0;
                bool relative = false;
                bool use_label = false;
                int label_addr = 0;
                
                //if there are 3 tokens, 
                if (tokens.size()==3) {
                    //set the address register to the last token
                    string arg = tokens[2];
                    //if the token is a label, parse it to an address, prohibiting iram
                    if (data_labels.find(arg)!=data_labels.end()) {
                        use_label = true;
                        label_addr = data_labels[arg];
                    } else if (instr_labels.find(arg)!=instr_labels.end()) {
                        throw runtime_error("instruction label used where data label is required: " + arg);
                    } else {
                        //and parse it as a register
                        base_reg = parse_reg(arg);
                    }
                
                //if there are 4 tokens,
                } else if (tokens.size()>=4) {
                    //we must be using the Ra, Rb, offset format
                    relative = true;
                    //set the base register properly
                    string arg = tokens[2];
                    if (data_labels.find(arg)!=data_labels.end()) {
                        use_label = true;
                        label_addr = data_labels[arg];
                    } else if (instr_labels.find(arg)!=instr_labels.end()) {
                        throw runtime_error("instruction label used where data label is required: " + arg);
                    } else {
                        base_reg = parse_reg(arg);
                    }
                    //ensure the offset is a signed value within range.
                    soff = parse_memory_offset(tokens[3]);
                }

                //if we're asking for a relative address with an offset (ie, a label with offset),
                if (relative && use_label) {
                    //copy the label into temp, add the offset, and load
                    emit_load_imm(words, ASM_TMP, label_addr + soff, addr, &word_comments, rawline);
                    instr = (ins_ldr<<12) | (r<<8) | (ASM_TMP<<4) | (0x0);
                //if we're asking for an address with an offset
                } else if (relative) {
                    if (soff < -8 || soff > 7) {
                        emit_memory_access(words, &word_comments, rawline,
                                           ins_ldr, r, base_reg, soff, addr);
                        continue;
                    }
                    instr = (ins_ldr<<12) | (r<<8) | (base_reg<<4) | (soff & 0xF);
                //if we're asking for a label with no offset
                } else if (use_label) {
                    //copy the label into temp, then load
                    emit_load_imm(words, ASM_TMP, label_addr, addr, &word_comments, rawline);
                    addr++;
                    instr = (ins_ldr<<12) | (r<<8) | (ASM_TMP<<4) | (0x0);
                } else {
                    //otherwise, we just emit the LDR instruction using the base register alone
                    instr = (ins_ldr<<12) | (r<<8) | (base_reg<<4);
                }

            //MOVI: load register lower half immediate
            } else if (op=="MOVI") {

                if (tokens.size()<3) throw runtime_error("MOVI expects R,IMM");

                int r = parse_reg(tokens[1]);
                int a;

                // immediate may be numeric or an address label in either memory space
                try {
                    a = parse_number(tokens[2]);
                } catch (...) {
                    a = resolve_any_label(instr_labels, data_labels, tokens[2]);
                }

                if (a<0||a>65535) throw runtime_error("immediate out of range");
                else if (a>255) {
                    // pseudoinstruction for 16-bit immediate load
                    // uses tmp register to load upper and lower halves
                    int upper = (a >> 8) & 0xFF;
                    int lower = a & 0xFF;
                    // first, load upper half into tmp
                    push_word((ins_movi<<12) | (ASM_TMP<<8) | (upper & 0xFF));
                    // then, shift tmp left by 8 bits
                    push_word((ins_shl<<12) | (ASM_TMP<<8) | (0x8<<4) | ASM_TMP);
                    // then, load lower half into tmp
                    push_word((ins_movi<<12) | (ASM_TMP<<8) | (lower & 0xFF));
                    addr += 3;
                    // finally, copy the completed value from tmp into the target register
                    instr = encode_alu(ins_and, ASM_TMP, ASM_TMP, r);
                } else {
                    // simple case: just OR the immediate into the lower half of the register
                    instr = (ins_movi<<12) | (r<<8) | (a & 0xFF);
                }


            //ADD: add two registers into a third
            } else if (op=="ADD") {

                if (tokens.size()<4) throw runtime_error("ADD expects RA,RB,RC");

                int ra=parse_reg(tokens[1]);
                int rb=parse_reg(tokens[2]);
                int rc=parse_reg(tokens[3]);
                instr = encode_alu(ins_add, rb, rc, ra);

            //ADDI: load an immediate into ASM_TMP, then add it to a register.
            } else if (op=="ADDI" || op=="SUBI" || op=="ORI" || op=="ANDI" || op=="MULTI") {

                if (tokens.size()!=4) throw runtime_error(op + " expects DEST,SOURCE,IMMEDIATE_OR_LABEL");

                int destination = parse_reg(tokens[1]);
                int source = parse_reg(tokens[2]);
                int immediate = 0;
                try {
                    immediate = parse_number(tokens[3]);
                } catch (...) {
                    immediate = resolve_any_label(instr_labels, data_labels, tokens[3]);
                }
                emit_load_imm(words, ASM_TMP, immediate, addr, &word_comments, rawline);

                int opcode = ins_add;
                if (op=="SUBI") opcode = ins_sub;
                else if (op=="ORI") opcode = ins_or;
                else if (op=="ANDI") opcode = ins_and;
                else if (op=="MULTI") opcode = ins_mult;
                instr = encode_alu(opcode, source, ASM_TMP, destination);


            //SUB: subtract two registers into a third
            } else if (op=="SUB") {

                if (tokens.size()<4) throw runtime_error("SUB expects RA,RB,RC");

                int ra=parse_reg(tokens[1]);
                int rb=parse_reg(tokens[2]);
                int rc=parse_reg(tokens[3]);
                instr = encode_alu(ins_sub, rb, rc, ra);


            //CMP: compare two registers and update the processor status flags.
            } else if (op=="CMP") {

                if (tokens.size()!=3) throw runtime_error("CMP expects RA,RB");

                int ra=parse_reg(tokens[1]);
                int rb=parse_reg(tokens[2]);
                instr = (ins_cmp_set<<12) | (ra<<8) | (rb<<4);


            //SETcc: write 0 or 1 to a register according to flags captured by CMP.
            } else if (op=="SETLT" || op=="SETEQ" || op=="SETNE" ||
                       op=="SETLE" || op=="SETGT" || op=="SETGE") {

                if (tokens.size()!=2) throw runtime_error(op + " expects DEST");

                int destination=parse_reg(tokens[1]);
                int condition = 0;
                if (op=="SETLT") condition = 0;
                else if (op=="SETEQ") condition = 1;
                else if (op=="SETNE") condition = 2;
                else if (op=="SETLE") condition = 3;
                else if (op=="SETGT") condition = 4;
                else condition = 5;
                instr = (ins_cmp_set<<12) | (destination<<8) | (condition<<4) | 0xF;


            //HLT: stop the processor
            } else if (op=="HLT" || op=="HALT") {
                instr = (ins_hlt<<12);


            //MOV: copy the source register into the destination via AND.
            } else if (op=="MOV") {

                if (tokens.size()<3) throw runtime_error("MOV expects DEST,SOURCE");

                int destination = parse_reg(tokens[1]);
                int source = parse_reg(tokens[2]);
                instr = encode_alu(ins_and, source, source, destination);


            //XOR: perform exclusive OR operation on two registers into a third
            } else if (op=="XOR") {

                if (tokens.size()<4) throw runtime_error("XOR expects RA,RB,RC");

                int ra=parse_reg(tokens[1]);
                int rb=parse_reg(tokens[2]);
                int rc=parse_reg(tokens[3]);

                // XOR = (A + B) - 2 * (A & B).
                // TMP holds the intersection; the destination holds the shift count temporarily.
                push_word(encode_alu(ins_and, ra, rb, ASM_TMP));
                push_word((ins_movi<<12) | (rc<<8) | 0x01);
                push_word((ins_shl<<12) | (ASM_TMP<<8) | (0x1<<4) | ASM_TMP);
                push_word(encode_alu(ins_add, ra, rb, rc));
                addr += 4;
                instr = encode_alu(ins_sub, rc, ASM_TMP, rc);


            //OR: perform OR operation on two registers into a third
            } else if (op=="OR") {

                if (tokens.size()<4) throw runtime_error("OR expects RA,RB,RC");

                int ra=parse_reg(tokens[1]);
                int rb=parse_reg(tokens[2]);
                int rc=parse_reg(tokens[3]);
                instr = encode_alu(ins_or, rb, rc, ra);


            //AND: perform AND operation on two registers into a third
            } else if (op=="AND") {

                if (tokens.size()<4) throw runtime_error("AND expects RA,RB,RC");

                int ra=parse_reg(tokens[1]);
                int rb=parse_reg(tokens[2]);
                int rc=parse_reg(tokens[3]);

                instr = encode_alu(ins_and, rb, rc, ra);


            //JMP: signed PC-relative jump using 12-bit immediate/label offset
            //      or an optional pseudo-form that copies a register value into the PC register.
            } else if (op=="JMP") {

                if (tokens.size()<2) throw runtime_error("JMP expects OFFSET_OR_LABEL_OR_REGISTER");

                if (instr_labels.find(tokens[1]) != instr_labels.end()) {
                    int target = instr_labels[tokens[1]];
                    int offset = target - (addr + 1);
                    if (offset < -2048 || offset > 2047) throw runtime_error("JMP offset out of range (-2048..2047)");
                    instr = (ins_jmp<<12) | ((uint16_t)offset & 0x0FFF);
                } else if (data_labels.find(tokens[1]) != data_labels.end()) {
                    throw runtime_error("data label used where instruction label is required: " + tokens[1]);
                } else {
                    try {
                        int offset = parse_number(tokens[1]);
                        if (offset < -2048 || offset > 2047) throw runtime_error("JMP offset out of range (-2048..2047)");
                        instr = (ins_jmp<<12) | ((uint16_t)offset & 0x0FFF);
                    } catch (...) {
                        int reg = parse_reg(tokens[1]);
                        // Pseudo-jump via ALU writeback format: RF[rc] = RF[ra] & RF[rb].
                        // Set ra=reg, rb=reg, rc=PC so PC receives reg's value.
                        instr = encode_alu(ins_and, reg, reg, PC);
                    }
                }


            //JNZ: if RF[rA] != 0 then jump to RF[rB] + signed 4-bit offset
            } else if (op=="JNZ") {

                if (tokens.size() < 3 || tokens.size() > 4) throw runtime_error("JNZ expects RA,RB[,OFFSET4]");

                int ra = parse_reg(tokens[1]);
                int rb = parse_reg(tokens[2]);
                int offset = 0;
                if (tokens.size() == 4) {
                    offset = parse_offset4(tokens[3]);
                }

                instr = (ins_jnz<<12) | (ra<<8) | (rb<<4) | ((uint16_t)offset & 0xF);

            //JLT: conditional signed less-than branch using signed 4-bit PC-relative offset
            } else if (op=="JLT") {

                if (tokens.size()<4) throw runtime_error("JLT expects RA,RB,OFFSET_OR_LABEL");
                int ra = parse_reg(tokens[1]);
                int rb = parse_reg(tokens[2]);
                int offset = 0;
                // offset can be numeric or label
                if (instr_labels.find(tokens[3])!=instr_labels.end()) {
                    int target = instr_labels[tokens[3]];
                    offset = target - (addr + 1);
                } else if (data_labels.find(tokens[3])!=data_labels.end()) {
                    throw runtime_error("data label used where instruction label is required: " + tokens[3]);
                } else {
                    offset = parse_number(tokens[3]);
                }
                if (offset < -8 || offset > 7) throw runtime_error("JLT offset out of range (-8..7)");
                uint16_t ob = (uint16_t)(offset & 0xF);
                instr = (ins_jlt<<12) | (ra<<8) | (rb<<4) | ob;

            // SHL: shifts rb left by a 4-bit immediate into ra
            } else if (op=="SHL") {
                if (tokens.size()<4) throw runtime_error("SHL expects DEST,SOURCE,SHIFT");

                int ra=parse_reg(tokens[1]);
                int rb=parse_reg(tokens[2]);
                int shift=parse_number(tokens[3]);
                if (shift < 0 || shift > 15) throw runtime_error("SHL shift amount out of range (0..15)");

                instr = (ins_shl<<12) | (rb<<8) | (shift<<4) | ra;

            // SHR: shifts rb right by a 4-bit immediate into ra
            } else if (op=="SHR") {
                if (tokens.size()<4) throw runtime_error("SHR expects DEST,SOURCE,SHIFT");

                int ra=parse_reg(tokens[1]);
                int rb=parse_reg(tokens[2]);
                int shift=parse_number(tokens[3]);
                if (shift < 0 || shift > 15) throw runtime_error("SHR shift amount out of range (0..15)");

                instr = (ins_shr<<12) | (rb<<8) | (shift<<4) | ra;

            //MULT: the heaviest ALU operation. multiplies two registers and puts result into a third register.
            } else if (op=="MULT") {

                if (tokens.size()<4) throw runtime_error("MULT expects RA,RB,RC");

                int ra=parse_reg(tokens[1]); int rb=parse_reg(tokens[2]); int rc=parse_reg(tokens[3]);
                instr = encode_alu(ins_mult, rb, rc, ra);
            } else {
                throw runtime_error(string("Unknown opcode: ")+op);
            }

        } catch (exception &e) {
            cerr<<"Error at instruction "<<addr<<": "<<e.what()<<" -> '"<<rawline<<"'\n";
            return 1;
        }
        push_word(instr);
        addr++;
    }

    // write plaintext output with one hex word per line
    ofstream ofs(outpath);
    if (!ofs) {
        cerr<<"Cannot open output "<<outpath<<"\n"; return 1;
    }
    for (auto w: words) {
        ofs << uppercase << hex << setw(4) << setfill('0') << w << '\n';
    }
    ofs.close();

    // data memory is separate hardware from instruction memory, so it gets its own plaintext output
    ofstream data_ofs(data_outpath);
    if (!data_ofs) {
        cerr<<"Cannot open data output "<<data_outpath<<"\n"; return 1;
    }
    for (auto w: data_words) {
        data_ofs << uppercase << hex << setw(4) << setfill('0') << w << '\n';
    }
    data_ofs.close();

    if (emit_mif) {
        try {
            write_mif_file(mif_outpath, words, 65536, word_comments);
            write_mif_file(data_mif_outpath, data_words, 65536, data_comments);
        } catch (exception &e) {
            cerr<<"Error writing MIF: "<<e.what()<<"\n";
            return 1;
        }
        cout<<"Assembled "<<words.size()<<" instruction words to "<<outpath<<" and "<<mif_outpath
            <<"; "<<data_words.size()<<" data words to "<<data_outpath<<" and "<<data_mif_outpath<<"\n";
    } else {
        cout<<"Assembled "<<words.size()<<" instruction words to "<<outpath
            <<"; "<<data_words.size()<<" data words to "<<data_outpath<<"\n";
    }
    return 0;
}