module proxy;

import std.file;
import std.json;
import std.socket;
import std.stdio;
import config;

int main(string[] args)
{
  if (args.length < 2)
  {
    writeln("Usage: proxy-program <config.json>");
    return 1;
  }
  
  auto cfg = new config.Config(args[1]);
  writeln("Config data ", cfg.data);

  // Reference: <https://arsdnet.net/dcode/book/chapter_02/03/server.d>
  auto listener = new Socket(AddressFamily.INET, SocketType.STREAM);
  listener.bind(new InternetAddress(cfg.get!string("host", "localhost"),
                                    cfg.get!ushort("port", 8443)));
  listener.listen(10);

  auto readSet = new SocketSet();
  Socket[] connectedClients;
  char[1024] buffer;
  bool isRunning = true;

  while (isRunning)
  {
    readSet.reset();
    readSet.add(listener);
    foreach(client; connectedClients) readSet.add(client);

    if (Socket.select(readSet, null, null))
    {
      // Client send data.
      foreach(client; connectedClients)
        if (readSet.isSet(client))
        {
          // Read from the client and echo it back.
          auto receivedData = client.receive(buffer);
          client.send(buffer[0 .. receivedData]);
        }

      // New connection.
      if (readSet.isSet(listener))
      {
        auto newSocket = listener.accept();
        newSocket.send("Hello!\n");
        connectedClients ~= newSocket;
      }
    }
  }
  
  return 0;
}
