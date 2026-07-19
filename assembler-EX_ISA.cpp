

/*
    Simple two-pass assembler for the project's EX_ISA.

    Usage: assembler-EX_ISA <input.asm> <output.txt>

    Assembly syntax (whitespace and commas separate tokens):
      - Labels: `label:` at start of a line
      - Comments: start with `;`, `//`, or `#`
      - Registers: R1 .. R14 (case-insensitive) or numeric 0..14 with R15 as TMP and R0 as zero register

    Instruction formats implemented :

      STR Rr, Rb, soff   -> 0001 raaa rbbb soff    (store RF[ra] -> D[RF[rb] + soff]), pseudo-ins variant accepts -8..+7 word offset
      LDR Rr, Rb, soff   -> 0010 raaa rbbb soff    (load D[RF[rb] + soff] -> RF[ra]), pseudo-ins variant accepts -8..+7 word offset

      ADD rA, rB, rC     -> 0011 raaa rbbb rccc
      SUB rA, rB, rC     -> 0100 raaa rbbb rccc
      HLT                -> 0101 0000 0000 0000

      MOVI rA, rB, hex   -> 0110 raaa dddddddd     (ORs the immediate value into the selected register, using pseudoins for >8 bits)
      OR  rA, rB, rC     -> 0111 raaa rbbb rccc
      AND rA, rB, rC     -> 1000 raaa rbbb rccc

      JMP addr           -> 1001 0000 bbbbbbbb    (absolute 8-bit instruction addr)
      JNZ addr, r        -> 1010 bbbbbbbb rrrr    (absolute addr, test reg)
      JLT rA, rB, offset -> 1011 raaa rbbb bbbb    (4-bit signed offset relative to next instr)

      SHL rA, rB, rC     -> 1100 raaa shft rccc     (added instructions for extra ALU ops)
      MULT rA, rB, rC    -> 1101 raaa rbbb rccc    
      SHR rA, rB, rC     -> 0000 raaa shft rccc

      NOP                -> 1000 0000 0000 0000   (AND R0 with R0 into R0, effectively a NOP)
      MOV rA, rB         -> 1000 raaa rbbb rccc    (AND RA with RA into RB, effectively moving) 
      XOR rA, rB, rC     -> pseudo-ins


    The assembler supports labels for addresses and computes relative offsets
    for `JLT` as: offset = target_address - (current_address + 1). Offset must fit
    in signed 4-bit (-8..+7).
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
        if (v < 1 || v > 14) throw runtime_error("register out of range: "+token);
        return v;
    }
    // as an alternate input, allow raw numbers 0-14 to convert properly too.
    {
        int v = stoi(s);
        if (v < 1 || v > 14) throw runtime_error("register out of range: "+token);
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

//loads a 16-bit immediate value into a register, using a temporary register if greater than 8 bits.
static void emit_load_imm(vector<uint16_t> &words, int reg, int value, int &addr) {
    if (value < 0 || value > 65535) throw runtime_error("immediate out of range");
    if (value > 255) {
        int upper = (value >> 8) & 0xFF;
        int lower = value & 0xFF;
        words.push_back((ins_movi<<12) | (15 << 8) | (upper & 0xFF));
        words.push_back((ins_shl<<12) | (15 << 8) | (15 << 4) | 0x1);
        words.push_back((ins_movi<<12) | (15 << 8) | (lower & 0xFF));
        words.push_back((ins_or<<12) | (reg << 8) | (15 << 4) | reg);
        addr += 4;
    } else {
        words.push_back((ins_movi<<12) | (reg << 8) | (value & 0xFF));
        addr++;
    }
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

    // dump all labels into a map the we create here
    unordered_map<string,int> labels;

    
    vector<string> norm_lines; 
    int addr = 0;

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
        // ignore empty lines
        if (l.empty()) continue;
        // label?
        if (l.back()==':') {
            // trim label to just title
            string lab = trim(l.substr(0,l.size()-1));
            // ignore it if empty
            if (lab.empty()) continue;
            // if it exists already, throw an error
            if (labels.find(lab)!=labels.end()) {
                cerr<<"Duplicate label "<<lab<<"\n"; return 1; }

            // store the address at the label
            labels[lab] = addr;
            continue;
        }
        // inline label at start: lab: instr
        size_t colon = l.find(':');
        // if the colon exists
        if (colon!=string::npos) {
            // trim the label again
            string lab = trim(l.substr(0,colon));
            // grab the rest of the string
            string rest = trim(l.substr(colon+1));
            // store the labels again
            labels[lab] = addr;
            l = rest;
            // repeat until all labels are processed
            if (l.empty()) continue;
        }
        norm_lines.push_back(l);
        addr += 1; // each instruction is one word
    }

    // Second pass: assemble
    vector<uint16_t> words;
    addr = 0;
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
                int base_reg = 15;
                int soff = 0;
                bool relative = false;
                
                //if there are 3 tokens, 
                if (tokens.size()==3) {
                    //set the address register to the last token
                    string arg = tokens[2];
                    //and parse it as a register
                    base_reg = parse_reg(arg);
                
                //if there are 4 tokens,
                } else if (tokens.size()>=4) {
                    //we must be using the Ra, Rb, offset format
                    relative = true;
                    //set the base register properly
                    base_reg = parse_reg(tokens[2]);
                    //ensure the offset is a signed value within range.
                    soff = parse_offset4(tokens[3]);
                }

                //if we're asking for a relative address (ie, an offset relative to an address),
                if (relative) {
                    //we load the offset value into the temp,
                    words.push_back((ins_movi<<12) | (15<<8) | (soff & 0xFF));
                    //then add the current offset to our base address, based on its sign, putting the result back into temp
                    if (soff >= 0) {
                        //now we emit an immediate load using a pointer to the address counter
                        emit_load_imm(words, 15, soff, addr);
                        words.push_back((ins_add<<12) | (15<<8) | (15<<4) | 0);
                    } else {
                        emit_load_imm(words, 0, -soff, addr);
                        words.push_back((ins_sub<<12) | (15<<8) | (15<<4) | 0);
                    }
                    addr++;
                    //finally, we emit the STR instruction using the temp register as the base address
                    instr = (ins_str<<12) | (r<<8) | (15<<4);
                } else {
                    //otherwise, we just emit the STR instruction using the base register
                    instr = (ins_str<<12) | (r<<8) | (base_reg<<4);
                }

            //LDR: load register through variable addressing
            } else if (op=="LDR" || op=="LOAD") {

                if (tokens.size()<3) throw runtime_error("LDR expects [Ra, Rb, offset] or [Ra, Rb]");

                int r = parse_reg(tokens[1]);
                int base_reg = 15;
                int soff = 0;
                bool relative = false;
                
                //if there are 3 tokens, 
                if (tokens.size()==3) {
                    //set the address register to the last token
                    string arg = tokens[2];
                    //and parse it as a register
                    base_reg = parse_reg(arg);
                
                //if there are 4 tokens,
                } else if (tokens.size()>=4) {
                    //we must be using the Ra, Rb, offset format
                    relative = true;
                    //set the base register properly
                    base_reg = parse_reg(tokens[2]);
                    //ensure the offset is a signed value within range.
                    soff = parse_offset4(tokens[3]);
                }

                //if we're asking for a relative address (ie, an offset relative to an address),
                if (relative) {
                    //we load the offset value into the temp,
                    words.push_back((ins_movi<<12) | (15<<8) | (soff & 0xFF));
                    //then add the current offset to our base address, based on its sign, putting the result back into temp
                    if (soff >= 0) {
                        //now we emit an immediate load using a pointer to the address counter
                        emit_load_imm(words, 15, soff, addr);
                        words.push_back((ins_add<<12) | (15<<8) | (15<<4) | 0);
                    } else {
                        emit_load_imm(words, 0, -soff, addr);
                        words.push_back((ins_sub<<12) | (15<<8) | (15<<4) | 0);
                    }
                    addr++;
                    //finally, we emit the LDR instruction using the temp register as the base address
                    instr = (ins_ldr<<12) | (r<<8) | (15<<4);
                } else {
                    //otherwise, we just emit the LDR instruction using the base register alone
                    instr = (ins_ldr<<12) | (r<<8) | (base_reg<<4);
                }
            
            //MOVI: load register lower half immediate
            } else if (op=="MOVI" || op=="MOVI") {

                if (tokens.size()<3) throw runtime_error("MOVI expects R,IMM");

                int r = parse_reg(tokens[1]);
                int a;

                // addr may be label
                if (labels.find(tokens[2])!=labels.end()) a = labels[tokens[2]];
                else a = parse_number(tokens[2]);

                if (a<0||a>65535) throw runtime_error("immediate out of range");
                else if (a>255) {
                    // pseudoinstruction for 16-bit immediate load
                    // uses tmp register to load upper and lower halves
                    int upper = (a >> 8) & 0xFF;
                    int lower = a & 0xFF;
                    // first, load upper half into tmp
                    words.push_back((ins_movi<<12) | (15<<8) | (upper & 0xFF));
                    // then, shift tmp left by 8 bits
                    words.push_back((ins_shl<<12) | (15<<8) | (15<<4) | 0x1);
                    // then, load lower half into tmp
                    words.push_back((ins_movi<<12) | (15<<8) | (lower & 0xFF));
                    addr += 3;
                    // finally, OR tmp into the target register
                    instr = (ins_or<<12) | (r<<8) | (15<<4) | r;
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


            //JMP: jump program counter to a direct address (within 256 words)
            } else if (op=="JMP") {

                if (tokens.size()<2) throw runtime_error("JMP expects ADDR");
                int a;

                if (labels.find(tokens[1])!=labels.end()) a = labels[tokens[1]];
                else a = parse_number(tokens[1]);

                if (a<0||a>255) throw runtime_error("JMP address out of range");
                instr = (ins_jmp<<12) | (0<<8) | (a & 0xFF);


            //JNZ: conditional branch on register not equal to zero to a direct address (within 256 words)
            } else if (op=="JNZ") {

                if (tokens.size()<3) throw runtime_error("JNZ expects ADDR,REG");
                int a;

                if (labels.find(tokens[1])!=labels.end()) a = labels[tokens[1]];

                else a = parse_number(tokens[1]);
                int r = parse_reg(tokens[2]);

                if (a<0||a>255) throw runtime_error("JNZ address out of range");
                instr = (ins_jnz<<12) | ((a & 0xFF)<<4) | (r & 0xF);

            //JNZ: conditional branch on register not equal to zero to a direct address (within 256 words)
            } else if (op=="JLT") {

                if (tokens.size()<4) throw runtime_error("JLT expects RA,RB,OFFSET_OR_LABEL");
                int ra = parse_reg(tokens[1]);
                int rb = parse_reg(tokens[2]);
                int offset = 0;
                // offset can be numeric or label
                if (labels.find(tokens[3])!=labels.end()) {
                    int target = labels[tokens[3]];
                    offset = target - (addr + 1);
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