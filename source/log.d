module log;

import std.stdio : writeln, writefln;

private void logImpl(string level, string message) =>
  writeln("[", level, "] ", message);

private void logImplf(Args...)(string level, string fmt, Args args) =>
  writefln("[" ~ level ~ "] " ~ fmt, args);

void info(Args...)(string fmt, Args args)
{
  static if (Args.length == 0) logImpl("INFO", fmt);
  else logImplf("INFO", fmt, args);
}

void error(Args...)(string fmt, Args args)
{
  static if (Args.length == 0) logImpl("ERROR", fmt);
  else logImplf("ERROR", fmt, args);
}

extern(C) int errorCallback(const(char)* str, size_t len, void* u)
{
  error(str[0 .. len-1].idup);
  return 1; // Required by OpenSSL callback signature.
}
