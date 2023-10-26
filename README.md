NOTE: This is a work in progress

```d
import seh;
import std.stdio;

void main()
{
	seh.register();

	int* x;

	writeln("Will now trigger a null reference exception");

	MyPreciousFunction();
}

void MyPreciousFunction()
{
	writeln("Doing wonderful stuff");

	int* x;

	*x = 1337;

	writeln("Wonderful, right?");
}
```

Run dub

Windows:
```cmd
Will now trigger a null reference exception
Doing wonderful stuff
-------------------------------------------------------------------+
Caught exception (0xC0000005)
-------------------------------------------------------------------+
C:\src\exceptiontest\source\app.d:21 - app.MyPreciousFunction
C:\src\exceptiontest\source\app.d:12 - D main
C:\src\exceptiontest\source\app.d:12 - _d_run_main2
C:\src\exceptiontest\source\app.d:12 - _d_run_main
C:\D\dmd2\windows\bin64\..\..\src\druntime\import\core\internal\entrypoint.d:29 - app._d_cmain!().main
D:\a\_work\1\s\src\vctools\crt\vcstartup\src\startup\exe_common.inl:288 - __scrt_common_main_seh
D:\a\_work\1\s\src\vctools\crt\vcstartup\src\startup\exe_common.inl:288 - BaseThreadInitThunk
D:\a\_work\1\s\src\vctools\crt\vcstartup\src\startup\exe_common.inl:288 - RtlUserThreadStart
```

OSX:
```bash
-------------------------------------------------------------------+
Received 'SIGSEGV' (0xB)
-------------------------------------------------------------------+
executable: /Users/macos/src/test/test
2   ???                                 0x0000000107084110 0x0 + 4412948752
3   test                                0x0000000103f492af _Dmain + 31
4   test                                0x0000000103f96109 _D2rt6dmain212_d_run_main2UAAamPUQgZiZ6runAllMFZv + 121
5   test                                0x0000000103f95e2e _d_run_main + 158
6   test                                0x0000000103f494c2 main + 34
7   libdyld.dylib                       0x00000001041e4235 start + 1
8   ???                                 0x0000000000000001 0x0 + 1
```

Linux:
```bash
-------------------------------------------------------------------+
Received 'SIGSEGV' (0xB)
-------------------------------------------------------------------+
executable: /home/johan/extest/extest
/home/johan/extest/source/app.d:21 +0x2421
/home/johan/extest/source/app.d:4 +0x23af
??:0 +0x434faf
??:0 +0x4352c6
??:0 _d_run_main+0x152
/usr/lib/gcc/x86_64-linux-gnu/10/include/d/__entrypoint.di:45 +0x23e6
??:0 __libc_start_main+0xf3
??:? +0x22ae
```


