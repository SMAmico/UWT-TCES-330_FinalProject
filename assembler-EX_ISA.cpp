

/*
    Simple two-pass assembler for the project's EX_ISA.

    Usage: assembler-EX_ISA <input.asm> <output.txt>

    Assembly syntax (whitespace and commas separate tokens):

      - Registers: R1 .. R13 (case-insensitive) or numeric 0..13 with R14 as TMP, R15 as PC, and R0 as zero register
      -- Assembly formatting instructions --
      - Use .text for instructions and instruction labels.
      - Use .data for data directives and data labels.
      - Labels end with ':' and may appear on their own line.
      - Tokens are separated by whitespace and/or commas.
      - Comments may start with ';', '//' or '#'.
      - Registers are R1..R13 (case-insensitive).
    - Control-flow labels (JMP/JLT label form) must be .text labels.
      - Memory-address labels (STR/LDR label form) must be .data labels.

    Instruction formats implemented :

      STR rA, rB/LABEL, soff (store RF[rA] -> D[RF[rB] + soff]) -> 0001 raaa rbbb soff  pseudo-ins variant accepts -8..+7 word offset
      LDR rA, rB/LABEL, soff (load D[RF[rB] + soff] -> RF[rA])  -> 0010 raaa rbbb soff  pseudo-ins variant accepts -8..+7 word offset

      ADD rA, rB, rC (rA = rB + rC)     -> 0011 raaa rbbb rccc
      SUB rA, rB, rC (rA = rB - rC)     -> 0100 raaa rbbb rccc
      HLT                               -> 0101 0000 0000 0000

      MOVI rA, rB, hex (rA = rB | hex)  -> 0110 raaa dddddddd     (ORs the immediate value into the selected register, using pseudoins for >8 bits)
      OR  rA, rB, rC   (rA = rB | rC)   -> 0111 raaa rbbb rccc
      AND rA, rB, rC   (rA = rB & rC)   -> 1000 raaa rbbb rccc

      JMP offset/LABEL (PC = PC + soff12) -> 1001 bbbb bbbb bbbb  (signed 12-bit PC-relative offset)
      JMP rA (optional pseudo-form: PC = RF[rA]) -> copies the register value into the PC register
      JNZ rA, rB, soff4 (PC = RF[rB] + soff4 if RF[rA] != 0) -> 1010 raaa rbbb bbbb
      JLT rA, rB, offset (PC = PC + offset if rA < rB) -> 1011 raaa rbbb bbbb    (4-bit signed offset relative to next instr)

      SHL rA, rB, rC   (rA = rB << rC)  -> 1100 raaa shft rccc     (added instructions for extra ALU ops)
      MULT rA, rB, rC  (rA = rB * rC)   -> 1101 raaa rbbb rccc    
      SHR rA, rB, rC   (rA = rB >> rC)  -> 0000 raaa shft rccc

      NOP                               -> 1000 0000 0000 0000   (AND R0 with R0 into R0, effectively a NOP)
      MOV rA, rB       (rA = rB)  -> 1000 raaa rbbb rccc    (AND RA with RA into RB, effectively moving) 
      XOR rA, rB, rC   (rA = rB ^ rC)   -> pseudo-ins


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

//REGISTER DEFINES: aliases for special registers in the ISA
#define reg_zero 0
#define PC 15
#define TMP 14


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
        if ((v < 1 || v > 13) || v == PC) throw runtime_error("register out of range: "+token);
        return v;
    }
    // as an alternate input, allow raw numbers 0-14 to convert properly too.
    {
        int v = stoi(s);
        if ((v < 1 || v > 13) || v == PC) throw runtime_error("register out of range: "+token);
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

//checks if a signed offset fits within a 4-bit length
static int parse_offset4(const string &token) {
    int value = parse_number(token);
    if (value < -8 || value > 7) throw runtime_error("offset out of range (-8..7)");
    return value;
}

//checks if an offset fits within a 16-bit signed value.
static int parse_offset16(const string &token) {
    int value = parse_number(token);
    if (value < -32768 || value > 32767) throw runtime_error("offset out of range (-32768..32767)");
    return value;
}

//loads a 16-bit immediate value into a register, using a temporary register if greater than 8 bits.
static void emit_load_imm(vector<uint16_t> &words, int reg, int value, int &addr) {
    if (value < 0 || value > 65535) throw runtime_error("immediate out of range");
    if (value > 255) {
        int upper = (value >> 8) & 0xFF;
        int lower = value & 0xFF;
        words.push_back((ins_movi<<12) | (TMP << 8) | (upper & 0xFF));
        words.push_back((ins_shl<<12) | (TMP << 8) | (TMP << 4) | 0x1);
        words.push_back((ins_movi<<12) | (TMP << 8) | (lower & 0xFF));
        words.push_back((ins_or<<12) | (reg << 8) | (TMP << 4) | reg);
        addr += 4;
    } else {
        words.push_back((ins_movi<<12) | (reg << 8) | (value & 0xFF));
        addr++;
    }
}

//converts a string to uppercase
static inline string upper_copy(string s) {
    for (auto &c : s) c = toupper((unsigned char)c);
    return s;
}

//tries to lookup a label in a table, returns true if found and sets value, false otherwise
static bool try_lookup_label(const unordered_map<string,int> &table, const string &name, int &value) {
    auto it = table.find(name);
    if (it == table.end()) return false;
    value = it->second;
    return true;
}

// @brief resolve a label to an address, checking both instruction and data label tables
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
    if (op == "XOR") return 4;
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
            return (addr > 255) ? 5 : 2;
        }
    }
    return 1;
}

//main loop
int main(int argc, char** argv) {
    //print input
    if (argc<3) {
        cerr<<"Usage: "<<argv[0]<<" <input.asm> <output.txt>\n";
        return 1;
    }
    //the paths for our input and output files
    string inpath = argv[1];
    string outpath = argv[2];

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

        //if we're in data, only allow .word and .space.
        if (section == Section::Data) {
            if (op == ".WORD") {
                //if .word, there must be at least one value to put in
                if (tokens.size() < 2) { cerr<<".word requires at least one value on line "<<(i+1)<<"\n"; return 1; }
                for (size_t k = 1; k < tokens.size(); ++k) {
                    try { (void)parse_number(tokens[k]); }
                    catch (...) { cerr<<"Invalid .word value '"<<tokens[k]<<"' on line "<<(i+1)<<"\n"; return 1; }
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
                data_addr += count;
                continue;
            }
            cerr<<"Only .word and .space are allowed in .data (line "<<(i+1)<<")\n";
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
    int addr = 0;
    for (auto &rawline: norm_lines) {
        string line = rawline;
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

            //STR: store register through variable addressing
            } else if (op=="STR") {

                if (tokens.size()<3) throw runtime_error("STR expects [Ra, Rb, offset] or [Ra, Rb]");

                int r = parse_reg(tokens[1]);
                int base_reg = TMP;
                int soff = 0;
                bool relative = false;
                bool use_label = false;
                int label_addr = 0;
                
                //if there are 3 tokens, 
                if (tokens.size()==3) {
                    //set the address register to the last token
                    string arg = tokens[2];
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
                    soff = parse_offset4(tokens[3]);
                }

                //if we're asking for a relative address (ie, an offset relative to an address),
                if (relative && use_label) {
                    emit_load_imm(words, TMP, label_addr + soff, addr);
                    instr = (ins_str<<12) | (r<<8) | (TMP<<4);
                } else if (relative) {
                    //small offsets still use the direct form
                    instr = (ins_str<<12) | (r<<8) | (base_reg<<4) | (soff & 0xF);
                } else if (use_label) {
                    emit_load_imm(words, TMP, label_addr, addr);
                    addr++;
                    instr = (ins_str<<12) | (r<<8) | (TMP<<4);
                } else {
                    //otherwise, we just emit the STR instruction using the base register
                    instr = (ins_str<<12) | (r<<8) | (base_reg<<4);
                }

            //LDR: load register through variable addressing
            } else if (op=="LDR" || op=="LOAD") {

                if (tokens.size()<3) throw runtime_error("LDR expects [Ra, Rb, offset] or [Ra, Rb]");

                int r = parse_reg(tokens[1]);
                int base_reg = TMP;
                int soff = 0;
                bool relative = false;
                bool use_label = false;
                int label_addr = 0;
                
                //if there are 3 tokens, 
                if (tokens.size()==3) {
                    //set the address register to the last token
                    string arg = tokens[2];
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
                    soff = parse_offset4(tokens[3]);
                }

                //if we're asking for a relative address (ie, an offset relative to an address),
                if (relative && use_label) {
                    emit_load_imm(words, TMP, label_addr + soff, addr);
                    instr = (ins_ldr<<12) | (r<<8) | (TMP<<4);
                } else if (relative) {
                    //small offsets still use the direct form
                    instr = (ins_ldr<<12) | (r<<8) | (base_reg<<4) | (soff & 0xF);
                } else if (use_label) {
                    emit_load_imm(words, TMP, label_addr, addr);
                    addr++;
                    instr = (ins_ldr<<12) | (r<<8) | (TMP<<4);
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
                    words.push_back((ins_movi<<12) | (TMP<<8) | (upper & 0xFF));
                    // then, shift tmp left by 8 bits
                    words.push_back((ins_shl<<12) | (TMP<<8) | (TMP<<4) | 0x1);
                    // then, load lower half into tmp
                    words.push_back((ins_movi<<12) | (TMP<<8) | (lower & 0xFF));
                    addr += 3;
                    // finally, OR tmp into the target register
                    instr = (ins_or<<12) | (r<<8) | (TMP<<4) | r;
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
                instr = (ins_add<<12) | (ra<<8) | (rb<<4) | rc;


            //SUB: subtract two registers into a third
            } else if (op=="SUB") {

                if (tokens.size()<4) throw runtime_error("SUB expects RA,RB,RC");

                int ra=parse_reg(tokens[1]);
                int rb=parse_reg(tokens[2]);
                int rc=parse_reg(tokens[3]);
                instr = (ins_sub<<12) | (ra<<8) | (rb<<4) | rc;


            //HLT: stop the processor
            } else if (op=="HLT" || op=="HALT") {
                instr = (ins_hlt<<12);


            //XOR: perform exclusive OR operation on two registers into a third
            } else if (op=="XOR") {

                if (tokens.size()<4) throw runtime_error("XOR expects RA,RB,RC");

                int ra=parse_reg(tokens[1]);
                int rb=parse_reg(tokens[2]);
                int rc=parse_reg(tokens[3]);

                //pseudoinstruction for XOR
                words.push_back((ins_add<<12) | (ra << 8) | (rb << 4) | rc);
                words.push_back((ins_and<<12) | (0xF<<8) | (rb << 4) | rc);
                words.push_back((ins_shl<<12) | (0xF<<8) | (0xF<<4) | 0x1);
                addr += 3;
                instr = (ins_sub<<12) | (ra<<8) | (ra << 4) | 0xF;


            //OR: perform OR operation on two registers into a third
            } else if (op=="OR") {

                if (tokens.size()<4) throw runtime_error("OR expects RA,RB,RC");

                int ra=parse_reg(tokens[1]);
                int rb=parse_reg(tokens[2]);
                int rc=parse_reg(tokens[3]);
                instr = (ins_or<<12) | (ra<<8) | (rb<<4) | rc;


            //AND: perform AND operation on two registers into a third
            } else if (op=="AND") {

                if (tokens.size()<4) throw runtime_error("AND expects RA,RB,RC");

                int ra=parse_reg(tokens[1]);
                int rb=parse_reg(tokens[2]);
                int rc=parse_reg(tokens[3]);

                instr = (ins_and<<12) | (ra<<8) | (rb<<4) | rc;


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
                        instr = (ins_and<<12) | (PC<<8) | (reg<<4) | reg;
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

            // SHL: shifts ra left by b into rc
            } else if (op=="SHL") {
                if (tokens.size()<4) throw runtime_error("SHL expects RA,RB,RC");

                int ra=parse_reg(tokens[1]);
                int rb=parse_reg(tokens[2]);
                int rc=parse_reg(tokens[3]);

                instr = (ins_shl<<12) | (ra<<8) | (rb<<4) | rc;

            // SHR: shifts ra right by b into rc
            } else if (op=="SHR") {
                if (tokens.size()<4) throw runtime_error("SHR expects RA,RB,RC");

                int ra=parse_reg(tokens[1]);
                int rb=parse_reg(tokens[2]);
                int rc=parse_reg(tokens[3]);

                instr = (ins_shr<<12) | (ra<<8) | (rb<<4) | rc;

            //MULT: the heaviest ALU operation. multiplies two registers and puts result into a third register.
            } else if (op=="MULT") {

                if (tokens.size()<4) throw runtime_error("MULT expects RA,RB,RC");

                int ra=parse_reg(tokens[1]); int rb=parse_reg(tokens[2]); int rc=parse_reg(tokens[3]);
                instr = (ins_mult<<12) | (ra<<8) | (rb<<4) | rc;
            } else {
                throw runtime_error(string("Unknown opcode: ")+op);
            }

        } catch (exception &e) {
            cerr<<"Error at instruction "<<addr<<": "<<e.what()<<" -> '"<<rawline<<"'\n";
            return 1;
        }
        words.push_back(instr);
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
    cout<<"Assembled "<<words.size()<<" words to "<<outpath<<"\n";
    return 0;
}