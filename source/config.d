module config;

import std.file;
import std.json;
import std.string;

// TODO: vibe.d library provides more abstractions for json than the standard
//       implementation. This manual value getter can be removed, however
//       using a whole library just to a parse a json file does not feel good.

class Config
{
  JSONValue data;

  this(string filepath)
  {
    this.data = parseJSON(readText(filepath));
  }

  T get(T)(string path, T defaultValue = T.init)
  {
    auto keys = path.split(".");
    auto current = this.data;

    foreach (key; keys)
    {
      if (current.type != JSONType.object) return defaultValue;
      auto child = key in current.object;
      if (child is null) return defaultValue;
      current = *child;
    }

    static if (is(T == string))
      return current.type == JSONType.string? current.str: defaultValue;
    else static if (is(T == ushort) || is(T == int) || is(T == long) || is(T == float))
    {
      if (current.type == JSONType.integer) return cast(T) current.integer;
      if (current.type == JSONType.float_) return cast(T) current.floating;
      return defaultValue;
    }
    else static if (is(T == bool))
      return current.type == JSONType.true_ ? true :
        current.type == JSONType.false_ ? false : defaultValue;
    else static if (is(T == JSONValue)) return current;   
    else static assert(false, "Unsupported type for Config.get");
  }
}
