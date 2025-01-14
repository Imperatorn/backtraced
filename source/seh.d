module seh;
import core.demangle;
import std.conv;
import std.algorithm.searching;
import std.system;
import std.string;

version (Windows)
{
    pragma(lib, "dbghelp.lib");
    import core.sys.windows.windows;
    import core.sys.windows.dbghelp;
    import core.stdc.stdlib : free, calloc;
    import core.stdc.stdio : fprintf, stderr;
    import core.stdc.string : memcpy, strncmp, strlen;

    struct SYMBOL_INFO
    {
        ULONG SizeOfStruct;
        ULONG TypeIndex;
        ULONG64[2] Reserved;
        ULONG Index;
        ULONG Size;
        ULONG64 ModBase;
        ULONG Flags;
        ULONG64 Value;
        ULONG64 Address;
        ULONG Register;
        ULONG Scope;
        ULONG Tag;
        ULONG NameLen;
        ULONG MaxNameLen;
        CHAR[1] Name;
    }

    extern (Windows) USHORT RtlCaptureStackBackTrace(ULONG FramesToSkip, ULONG FramesToCapture, PVOID* BackTrace, PULONG BackTraceHash);
    extern (Windows) BOOL SymFromAddr(HANDLE hProcess, DWORD64 Address, PDWORD64 Displacement, SYMBOL_INFO* Symbol);
    extern (Windows) BOOL SymGetLineFromAddr64(HANDLE hProcess, DWORD64 dwAddr, PDWORD pdwDisplacement, IMAGEHLP_LINEA64* line);

    extern (Windows) LONG TopLevelExceptionHandler(PEXCEPTION_POINTERS pExceptionInfo)
    {
        fprintf(stderr, "-------------------------------------------------------------------+\r\n");
        fprintf(stderr, "Caught exception (0x%X)\r\n", pExceptionInfo.ExceptionRecord.ExceptionCode);
        fprintf(stderr, "-------------------------------------------------------------------+\r\n");

        enum MAX_DEPTH = 32;
        void*[MAX_DEPTH] stack;

        HANDLE process = GetCurrentProcess();

        SymInitialize(process, null, true);
        SymSetOptions(SYMOPT_LOAD_LINES);

        ushort frames = RtlCaptureStackBackTrace(0, MAX_DEPTH, stack.ptr, null);
        SYMBOL_INFO* symbol = cast(SYMBOL_INFO*) calloc((SYMBOL_INFO.sizeof) + 256 * char.sizeof, 1);
        symbol.MaxNameLen = 255;
        symbol.SizeOfStruct = SYMBOL_INFO.sizeof;

        IMAGEHLP_LINEA64 line = void;
        line.SizeOfStruct = SYMBOL_INFO.sizeof;

        DWORD dwDisplacement;

        for (uint i = 0; i < frames; i++)
        {
            SymFromAddr(process, cast(DWORD64)(stack[i]), null, symbol);
            SymGetLineFromAddr64(process, cast(DWORD64)(stack[i]), &dwDisplacement, &line);

            // auto f = frames - i - 1;
            auto s = fromStringz(symbol.Name.ptr);

            auto funcName = demangle(s);
            auto fname = line.FileName;
            auto lnum = line.LineNumber;

            if (ends_with(fname, __FILE__) || funcName.canFind("rt.dmain2._d_run_main2"))
                continue; // skip trace from this module

            fprintf(stderr, "%s:%i - %s\n", fname, lnum, toStringz(funcName));
        }
        free(symbol);
        return EXCEPTION_CONTINUE_SEARCH;
    }

    int ends_with(const(char)* str, const(char)* suffix)
    {
        if (!str || !suffix)
            return 0;
        size_t lenstr = strlen(str);
        size_t lensuffix = strlen(suffix);
        if (lensuffix > lenstr)
            return 0;
        return strncmp(str + lenstr - lensuffix, suffix, lensuffix) == 0;
    }

    extern (C) export void register()
    {
        SetUnhandledExceptionFilter(&TopLevelExceptionHandler);
    }
}

version (OSX)
{
    version = cool;
    import core.stdc.stdlib;
    import core.stdc.string;
    import core.sys.posix.unistd;
    import core.stdc.stdio : fprintf, stderr, sprintf, fgets, fclose, FILE;
    import core.sys.posix.stdio;
    import core.sys.posix.signal;
    import core.sys.darwin.execinfo;
    import core.sys.posix.dlfcn;
    import core.demangle : demangle;

    extern (C) int _NSGetExecutablePath(char* buf, uint* bufsize) nothrow;
}
else version (Posix)
{
    version = cool;
    import core.stdc.signal : SIGSEGV, SIGFPE, SIGILL, SIGABRT, signal;
    import core.stdc.stdlib : free, exit;
    import core.stdc.string : strlen, memcpy;
    import core.stdc.stdio : fprintf, stderr, sprintf, fgets, fclose, FILE;
    import core.sys.posix.unistd;
    import core.sys.posix.signal : SIGUSR1;
    import core.sys.posix.stdio : popen, pclose;
    import core.sys.linux.execinfo : backtrace, backtrace_symbols;
    import core.sys.linux.dlfcn : dladdr, dladdr1, Dl_info, RTLD_DL_LINKMAP;
    import core.sys.linux.link : link_map;
    import core.demangle : demangle;
}

version (cool)
{
    extern (C) export void register()
    {
        extern (C) void function(int) nothrow @nogc nogcHandler = cast(
            void function(int) nothrow @nogc)&handler;

        signal(SIGSEGV, nogcHandler);
        signal(SIGUSR1, nogcHandler);
    }

    extern (C) void handler(int sig) nothrow
    {
        enum MAX_DEPTH = 32;

        string signal_string;
        switch (sig)
        {
        case SIGSEGV:
            signal_string = "SIGSEGV";
            break;
        case SIGFPE:
            signal_string = "SIGFPE";
            break;
        case SIGILL:
            signal_string = "SIGILL";
            break;
        case SIGABRT:
            signal_string = "SIGABRT";
            break;
        default:
            signal_string = "unknown";
            break;
        }

        fprintf(stderr, "-------------------------------------------------------------------+\r\n");
        fprintf(stderr, "Received '%s' (0x%X)\r\n", signal_string.ptr, sig);
        fprintf(stderr, "-------------------------------------------------------------------+\r\n");

        void*[MAX_DEPTH] trace;
        int stack_depth = backtrace(&trace[0], MAX_DEPTH);
        char** strings = backtrace_symbols(&trace[0], stack_depth);

        enum BUF_SIZE = 1024;
        char[BUF_SIZE] syscom = 0;
        char[BUF_SIZE] my_exe = 0;
        char[BUF_SIZE] output = 0;

        version (OSX)
        {
            uint bufsize = BUF_SIZE;
            _NSGetExecutablePath(cast(char*) my_exe, &bufsize);
        }
        else
            readlink("/proc/self/exe", &my_exe[0], BUF_SIZE);

        fprintf(stderr, "executable: %s\n", &my_exe[0]);

        for (auto i = 2; i < stack_depth; ++i)
        {
            auto line = strings[i];
            auto len = strlen(line);

            version (OSX)
            {
                puts(&line[0]);
            }
            else
            {
                bool insideParenthesis;
                int startParenthesis;
                int endParenthesis;
                for (int j = 0; j < len; j++)
                {
                    if (!insideParenthesis && line[j] == '(')
                    {
                        insideParenthesis = true;
                        startParenthesis = j + 1;
                    }
                    else if (insideParenthesis && line[j] == ')')
                    {
                        insideParenthesis = false;
                        endParenthesis = j;
                    }
                }

                size_t addr = convert_to_vma(cast(size_t) trace[i]);

                FILE* fp;

                sprintf(&syscom[0], "addr2line -e %s %p", &my_exe[0], addr);

                fp = popen(&syscom[0], "r");

                fgets(&output[0], output.length, fp);
                fclose(fp);

                auto getLen = strlen(output.ptr);

                char[256] func = 0;
                memcpy(func.ptr, &line[startParenthesis], (endParenthesis - startParenthesis));

                auto s = fromStringz(func.ptr);

                auto funcName = demangle(s);

                sprintf(&syscom[0], "echo '%s'", toStringz(funcName));

                fp = popen(&syscom[0], "r");

                if (getLen > 1)
                {
                    output[getLen - 1] = ' ';
                    fgets(&output[getLen], cast(int)(output.length - getLen), fp);
                }

                fclose(fp);

                fprintf(stderr, "%s", output.ptr);
            }
        }

        exit(0);
    }

    // https://stackoverflow.com/questions/56046062/linux-addr2line-command-returns-0/63856113#63856113
    size_t convert_to_vma(size_t addr) nothrow @nogc
    {
        version (OSX)
        {
            Dl_info info;
            dladdr(cast(void*) addr, &info);

            uintptr_t offset = cast(uintptr_t) addr - cast(uintptr_t) info.dli_fbase;

            return offset;
        }
        else
        {
            Dl_info info;
            link_map* link_map;
            dladdr1(cast(void*) addr, &info, cast(void**)&link_map, RTLD_DL_LINKMAP);
            return addr - link_map.l_addr;
        }
    }
}
