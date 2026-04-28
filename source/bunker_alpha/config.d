module bunker_alpha.config;

import std.file;
import std.json;
import std.string;
import std.typecons : Nullable, nullable;

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

  T getOrDefault(T)(string path, T defaultValue = T.init)
  {
    auto value = this.get!T(path);
    return value.isNull ? defaultValue : value.get;
  }

  Nullable!T get(T)(string path)
  {
    auto keys = path.split(".");
    auto current = this.data;

    foreach (key; keys)
    {
      if (current.type != JSONType.object) return Nullable!T();
      auto child = key in current.object;
      if (child is null) return Nullable!T();
      current = *child;
    }

    static if (is(T == string))
      return current.type == JSONType.string
        ? nullable(current.str)
        : Nullable!T();
    else static if (is(T == ushort) || is(T == int) || is(T == long) ||
                    is(T == float))
    {
      if (current.type == JSONType.integer)
        return nullable(cast(T) current.integer);
      if (current.type == JSONType.float_)
        return nullable(cast(T) current.floating);
      return Nullable!T();
    }
    else static if (is(T == bool))
      return current.type == JSONType.true_ ? nullable(true) :
        current.type == JSONType.false_ ? nullable(false) : Nullable!T();
    else static if (is(T == JSONValue)) return nullable(current);
    else static assert(false, "Unsupported type for Config.get");
  }
}
