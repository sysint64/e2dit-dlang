module e2ml.stream;

import std.stdio;
import std.file;
import core.stdc.stdio;


class SymbolStream {
public:
    char read() {
        auto buf = file.rawRead(new char[1]);

        if (file.eof) lastChar = 255;
        else lastChar = buf[0];

        return lastChar;
    }

    this(in string fileName) {
        assert(fileName.isFile);
        this.file = File(fileName);
    }

    void lockLineBreak() { isLockLineBreak = true; }
    void unlockLineBreak() { isLockLineBreak = false; }

    @property int line() { return p_line; }
    @property int pos() { return p_pos; }
    @property bool eof() { return file.eof; }
    @property char lastChar() { return p_lastChar; }

private:
    File file;
    int p_line, p_pos;
    char p_lastChar;
    bool isLockLineBreak = false;

    @property void lastChar(char val) { p_lastChar = val; }
}
