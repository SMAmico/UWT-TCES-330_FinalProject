/*
    write an assembler file that converts from a plaintext file containing
    assembly code to a plaintext file containing machine code. the instruction set is 
    translated as follows:
    INS_NOP = 4'h0,
    INS_STR = 4'h1, 0001 rrrr dddddddd RF[rrrr] -> D[dddddddd]
    INS_LDR = 4'h2, 0010 dddddddd rrrr
    INS_ADD = 4'h3, all simple operations follow: 0011 raaa rbbb rccc RF[rccc] = RF[raaa] (ALUop) RF[rbbb]
    INS_SUB = 4'h4, 
    INS_HLT = 4'h5,
    INS_XOR = 4'h6,
    INS_OR =  4'h7,
    INS_AND = 4'h8,
    INS_JMP = 4'h9, 1001 0000 bbbbbbbb
    INS_JNZ = 4'hA, 1010 bbbbbbbb rrrr, where b is the address
    INS_JLT = 4'hB, 1011 raaa rbbb bbbb, where bbbb is the offset
    INS_SHL = 4'hC, //SHL shifts by one bit
    INS_MULT= 4'hD;

    The device has 16 registers accessible, with . the instructions are formatted:

*/

/*
    Simple two-pass assembler for the project's EX_ISA.

    Usage: assembler-EX_ISA <input.asm> <output.txt>

    Assembly syntax (whitespace and commas separate tokens):
      - Labels: `label:` at start of a line
      - Comments: start with `;`, `//`, or `#`
      - Registers: R0 .. R15 (case-insensitive) or numeric 0..15

    Instruction formats implemented (match FSM expectations):
      NOP                 -> 0000 0000 0000 0000
      STR Rr, addr        -> 0001 rrrr dddddddd    (store RF[r] -> D[addr])
      LDR addr, Rr        -> 0010 dddddddd rrrr    (load D[addr] -> RF[r])
      ADD rA, rB, rC     -> 0011 raaa rbbb rccc
      SUB rA, rB, rC     -> 0100 raaa rbbb rccc
      HLT                 -> 0101 0000 0000 0000
      XOR rA, rB, rC     -> 0110 raaa rbbb rccc
      OR  rA, rB, rC     -> 0111 raaa rbbb rccc
      AND rA, rB, rC     -> 1000 raaa rbbb rccc
      JMP addr            -> 1001 0000 bbbbbbbb    (absolute addr)
      JNZ addr, r        -> 1010 bbbbbbbb rrrr    (absolute addr, test reg)
      JLT rA, rB, offset -> 1011 raaa rbbb bbbb    (4-bit signed offset relative to next instr)
      SHL rA, rB, rC     -> 1100 raaa rbbb rccc
      MULT rA, rB, rC    -> 1101 raaa rbbb rccc

    The assembler supports labels for addresses and computes relative offsets
    for `JLT` as: offset = target_address - (current_address + 1). Offset must fit
    in signed 4-bit (-8..+7).

    Output: plaintext file containing one 16-bit machine word per line in hexadecimal.
*/

#include <algorithm>
#include <cctype>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <unordered_map>
#include <vector>
using namespace std;

static inline string trim(const string &s) {
    size_t a = s.find_first_not_of(" \t\r\n");
    if (a==string::npos) return "";
    size_t b = s.find_last_not_of(" \t\r\n");
    return s.substr(a, b-a+1);
}

static inline vector<string> split_tokens(const string &line) {
    vector<string> toks;
    string cur;
    for (size_t i=0;i<line.size();) {
        if (isspace((unsigned char)line[i]) || line[i]==',') { i++; continue; }
        if (line[i]=='/' && i+1<line.size() && line[i+1]=='/') break;
        if (line[i]==';' || line[i]=='#') break;
        // token: read until whitespace or comma
        size_t j=i;
        while (j<line.size() && !isspace((unsigned char)line[j]) && line[j]!=',') j++;
        toks.push_back(line.substr(i, j-i));
        i=j;
    }
    return toks;

}

int parse_reg(const string &tok) {
    string s = tok;
    for (auto &c: s) c = toupper((unsigned char)c);
    if (s.size()>0 && s[0]=='R') {
        string num = s.substr(1);
        int v = stoi(num);
        if (v<0||v>15) throw runtime_error("register out of range: "+tok);
        return v;
    }
    // allow raw numbers 0..15
    {
        int v = stoi(s);
        if (v<0||v>15) throw runtime_error("register out of range: "+tok);
        return v;
    }
}

int parse_number(const string &tok) {
    string s = tok;
    if (s.size()>1 && s[0]=='0' && (s[1]=='x' || s[1]=='X')) {
        return stoi(s,nullptr,16);
    }
    if (s.size()>1 && s[0]=='-') {
        return stoi(s,nullptr,0);
    }
    // decimal by default
    return stoi(s,nullptr,0);
}

int main(int argc, char** argv) {
    if (argc<3) {
        cerr<<"Usage: "<<argv[0]<<" <input.asm> <output.txt>\n";
        return 1;
    }
    string inpath = argv[1];
    string outpath = argv[2];

    vector<string> lines;
    {
        ifstream ifs(inpath);
        if (!ifs) { cerr<<"Cannot open "<<inpath<<"\n"; return 1; }
        string raw;
        while (getline(ifs, raw)) lines.push_back(raw);
    }

    // First pass: collect labels and normalize lines
    unordered_map<string,int> labels;
    vector<string> norm_lines; // lines without labels/comments
    int addr = 0;
    for (size_t i=0;i<lines.size();++i) {
        string l = lines[i];
        // remove comments
        size_t cpos = l.find("//");
        size_t cpos2 = l.find(';');
        if (cpos2!=string::npos && (cpos==string::npos || cpos2<cpos)) cpos = cpos2;
        size_t cpos3 = l.find('#');
        if (cpos3!=string::npos && (cpos==string::npos || cpos3<cpos)) cpos = cpos3;
        if (cpos!=string::npos) l = l.substr(0,cpos);
        l = trim(l);
        if (l.empty()) continue;
        // label?
        if (l.back()==':') {
            string lab = trim(l.substr(0,l.size()-1));
            if (lab.empty()) continue;
            if (labels.find(lab)!=labels.end()) {
                cerr<<"Duplicate label "<<lab<<"\n"; return 1; }
            labels[lab] = addr;
            continue;
        }
        // inline label at start: lab: instr
        size_t colon = l.find(':');
        if (colon!=string::npos) {
            string lab = trim(l.substr(0,colon));
            string rest = trim(l.substr(colon+1));
            labels[lab] = addr;
            l = rest;
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
        auto toks = split_tokens(line);
        if (toks.empty()) { addr++; continue; }
        string op = toks[0];
        for (auto &c: op) c = toupper((unsigned char)c);
        uint16_t instr = 0;
        try {
            if (op=="NOP") {
                instr = 0x0000;
            } else if (op=="STR") {
                if (toks.size()<3) throw runtime_error("STR expects R,ADDR");
                int r = parse_reg(toks[1]);
                int a;
                // addr may be label
                if (labels.find(toks[2])!=labels.end()) a = labels[toks[2]];
                else a = parse_number(toks[2]);
                if (a<0||a>255) throw runtime_error("address out of range");
                instr = (0x1<<12) | (r<<8) | (a & 0xFF);
            } else if (op=="LDR" || op=="LOAD") {
                if (toks.size()<3) throw runtime_error("LDR expects ADDR,R");
                int a;
                if (labels.find(toks[1])!=labels.end()) a = labels[toks[1]];
                else a = parse_number(toks[1]);
                int r = parse_reg(toks[2]);
                if (a<0||a>255) throw runtime_error("address out of range");
                instr = (0x2<<12) | ((a & 0xFF)<<4) | (r & 0xF);
            } else if (op=="ADD") {
                if (toks.size()<4) throw runtime_error("ADD expects RA,RB,RC");
                int ra=parse_reg(toks[1]); int rb=parse_reg(toks[2]); int rc=parse_reg(toks[3]);
                instr = (0x3<<12) | (ra<<8) | (rb<<4) | rc;
            } else if (op=="SUB") {
                if (toks.size()<4) throw runtime_error("SUB expects RA,RB,RC");
                int ra=parse_reg(toks[1]); int rb=parse_reg(toks[2]); int rc=parse_reg(toks[3]);
                instr = (0x4<<12) | (ra<<8) | (rb<<4) | rc;
            } else if (op=="HLT" || op=="HALT") {
                instr = (0x5<<12);
            } else if (op=="XOR") {
                if (toks.size()<4) throw runtime_error("XOR expects RA,RB,RC");
                int ra=parse_reg(toks[1]); int rb=parse_reg(toks[2]); int rc=parse_reg(toks[3]);
                instr = (0x6<<12) | (ra<<8) | (rb<<4) | rc;
            } else if (op=="OR") {
                if (toks.size()<4) throw runtime_error("OR expects RA,RB,RC");
                int ra=parse_reg(toks[1]); int rb=parse_reg(toks[2]); int rc=parse_reg(toks[3]);
                instr = (0x7<<12) | (ra<<8) | (rb<<4) | rc;
            } else if (op=="AND") {
                if (toks.size()<4) throw runtime_error("AND expects RA,RB,RC");
                int ra=parse_reg(toks[1]); int rb=parse_reg(toks[2]); int rc=parse_reg(toks[3]);
                instr = (0x8<<12) | (ra<<8) | (rb<<4) | rc;
            } else if (op=="JMP") {
                if (toks.size()<2) throw runtime_error("JMP expects ADDR");
                int a;
                if (labels.find(toks[1])!=labels.end()) a = labels[toks[1]];
                else a = parse_number(toks[1]);
                if (a<0||a>255) throw runtime_error("JMP address out of range");
                instr = (0x9<<12) | (0<<8) | (a & 0xFF);
            } else if (op=="JNZ") {
                if (toks.size()<3) throw runtime_error("JNZ expects ADDR,REG");
                int a;
                if (labels.find(toks[1])!=labels.end()) a = labels[toks[1]];
                else a = parse_number(toks[1]);
                int r = parse_reg(toks[2]);
                if (a<0||a>255) throw runtime_error("JNZ address out of range");
                instr = (0xA<<12) | ((a & 0xFF)<<4) | (r & 0xF);
            } else if (op=="JLT") {
                if (toks.size()<4) throw runtime_error("JLT expects RA,RB,OFFSET_OR_LABEL");
                int ra = parse_reg(toks[1]);
                int rb = parse_reg(toks[2]);
                int offset = 0;
                // offset can be numeric or label
                if (labels.find(toks[3])!=labels.end()) {
                    int target = labels[toks[3]];
                    offset = target - (addr + 1);
                } else {
                    offset = parse_number(toks[3]);
                }
                if (offset < -8 || offset > 7) throw runtime_error("JLT offset out of range (-8..7)");
                uint16_t ob = (uint16_t)(offset & 0xF);
                instr = (0xB<<12) | (ra<<8) | (rb<<4) | ob;
            } else if (op=="SHL") {
                if (toks.size()<4) throw runtime_error("SHL expects RA,RB,RC");
                int ra=parse_reg(toks[1]); int rb=parse_reg(toks[2]); int rc=parse_reg(toks[3]);
                instr = (0xC<<12) | (ra<<8) | (rb<<4) | rc;
            } else if (op=="MULT") {
                if (toks.size()<4) throw runtime_error("MULT expects RA,RB,RC");
                int ra=parse_reg(toks[1]); int rb=parse_reg(toks[2]); int rc=parse_reg(toks[3]);
                instr = (0xD<<12) | (ra<<8) | (rb<<4) | rc;
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
    if (!ofs) { cerr<<"Cannot open output "<<outpath<<"\n"; return 1; }
    for (auto w: words) {
        ofs << uppercase << hex << setw(4) << setfill('0') << w << '\n';
    }
    ofs.close();
    cout<<"Assembled "<<words.size()<<" words to "<<outpath<<"\n";
    return 0;
}