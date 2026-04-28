module bunker_alpha.server;

import std.socket;
import deimos.openssl.err;
import deimos.openssl.ssl;
import config = bunker_alpha.config;
import connection = bunker_alpha.connection;
import log = bunker_alpha.log;

void runServer(SSL_CTX* sslContext, config.Config cfg)
{
  auto host = cfg.getOrDefault!string("host", "localhost");
  auto port = cfg.getOrDefault!ushort("port", 8443);
  auto url = cfg.getOrDefault!string("url", "https://" ~ host);
  auto backlog = cfg.getOrDefault!int("backlog", 10);

  // Reference: <https://arsdnet.net/dcode/book/chapter_02/03/server.d>
  auto listener = new Socket(AddressFamily.INET, SocketType.STREAM);
  listener.bind(new InternetAddress(host, port));
  listener.listen(backlog);
  log.info("Listening on %s:%d with a backlog of %d.", url, port, backlog);

  auto readSet = new SocketSet();
  connection.ClientConnection[] connectedClients;
  char[1024] buffer;
  bool isRunning = true;

  // TODO: Make this asynchronous.
  while (isRunning)
  {
    readSet.reset();
    readSet.add(listener);
    foreach(client; connectedClients) readSet.add(client.sock);

    if (Socket.select(readSet, null, null))
    {
      // New connection.
      if (readSet.isSet(listener))
      {
        auto sock = listener.accept();

        auto ssl = SSL_new(sslContext);
        SSL_set_fd(ssl, sock.handle);

        if (SSL_accept(ssl) <= 0)
        {
          ERR_print_errors_cb(&log.errorCallback, null);
          sock.close();
          SSL_free(ssl);
        }
        else
        {
          log.info("TLS client connected.");
          connectedClients ~= connection.ClientConnection(sock, ssl);
        }
      }

      // Client send data.
      foreach(i, ref client; connectedClients)
        if (readSet.isSet(client.sock))
        {
          connection.handleClient(client, buffer[]);
          if (SSL_get_shutdown(client.ssl))
          {
            // TODO: Use a better data structure.
            connectedClients[i] = connectedClients[$-1];
            connectedClients = connectedClients[0 .. $-1];
            break;
          }
        }
    }
  }

  // TODO: Capture signals for graceful clean up.
  // Clean up.
  listener.close();
}
