module proxy;

import std.file;
import std.json;
import std.socket;
import std.stdio;

import deimos.openssl.err;
import deimos.openssl.ssl;

import config : Config;
import log;

struct ClientConnection
{
  Socket sock;
  SSL* ssl;

  // Apparently, defining the toHash method is required because DMD is unable to generate TypeInfo.
  // Reference: <https://forum.dlang.org/post/q25ib0$2cco$1@digitalmars.com>
  size_t toHash() const @safe nothrow => cast(size_t) ssl ^ cast(size_t) sock.handle;
  bool opEquals(const ClientConnection other) const @safe nothrow
       => ssl == other.ssl && sock.handle == other.sock.handle;
}

void handleClient(ref ClientConnection client, char[] buffer)
{
  int bytes = SSL_read(client.ssl, buffer.ptr, cast(int) buffer.length);
  if (bytes <= 0)
  {
    auto err = SSL_get_error(client.ssl, bytes);
    if (err == SSL_ERROR_ZERO_RETURN) log.info("Client connection terminated gracefully.");
    else ERR_print_errors_cb(&log.errorCallback, null);

    SSL_shutdown(client.ssl);
    SSL_free(client.ssl);
    client.sock.close();
    return;
  }

  // Echo back.
  int bytesWritten = 0;
  while (bytesWritten < bytes)
  {
    int sent = SSL_write(client.ssl, buffer.ptr + bytesWritten, bytes - bytesWritten);
    if (sent <= 0)
    {
      ERR_print_errors_cb(&log.errorCallback, null);
      break;
    }
    bytesWritten += sent;
  }
}

int main(string[] args)
{
  if (args.length < 2)
  {
    writeln("Usage: proxy-program <config.json>");
    return 1;
  }
  
  auto cfg = new Config(args[1]);

  // OpenSSL initialisation.
  SSL_load_error_strings();
  OpenSSL_add_ssl_algorithms();
  auto sslContext = SSL_CTX_new(TLS_server_method());
  // TODO: TLS configuration is weak, harden it.

  // Load certificate and private key.
  {
    auto certificateValue = cfg.get!string("certificate-path");
    if (certificateValue.isNull)
    {
      log.error("The certificate path is not configured. " ~
                "Please specify it using the \"certificate-path\" field.");
      SSL_CTX_free(sslContext);
      return 1;
    }

    auto privateKeyValue = cfg.get!string("key-path");
    if (privateKeyValue.isNull)
    {
      log.error("The private key path is not configured. " ~
                "Please specify it using the \"key-path\" field.");
      SSL_CTX_free(sslContext);
      return 1;
    }

    if (SSL_CTX_use_certificate_file(sslContext, certificateValue.get.ptr, SSL_FILETYPE_PEM) != 1)
    {
      ERR_print_errors_cb(&log.errorCallback, null);
      SSL_CTX_free(sslContext);
      return 1;
    }

    if (SSL_CTX_use_PrivateKey_file(sslContext, privateKeyValue.get.ptr, SSL_FILETYPE_PEM) != 1)
    {
      ERR_print_errors_cb(&log.errorCallback, null);
      SSL_CTX_free(sslContext);
      return 1;
    }

    if (SSL_CTX_check_private_key(sslContext) != 1)
    {
      log.error("Private key does not match the certificate.");
      SSL_CTX_free(sslContext);
      return 1;
    }
  }

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
  ClientConnection[] connectedClients;
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
          connectedClients ~= ClientConnection(sock, ssl);
        }
      }

      // Client send data.
      foreach(i, ref client; connectedClients)
        if (readSet.isSet(client.sock))
        {
          handleClient(client, buffer[]);
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

  // Clean up.
  listener.close();
  SSL_CTX_free(sslContext);
  return 0;
}
