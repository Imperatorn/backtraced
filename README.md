NOTE: This is a work in progress. Not expected to work on Mac yet

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

Output:
```
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

