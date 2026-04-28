module bunker_alpha.connection;

import std.socket;
import deimos.openssl.err;
import deimos.openssl.ssl;
import log = bunker_alpha.log;

struct ClientConnection
{
  Socket sock;
  SSL* ssl;

  // Apparently, defining the toHash method is required,
  // because DMD is unable to generate TypeInfo.
  // Reference: <https://forum.dlang.org/post/q25ib0$2cco$1@digitalmars.com>
  size_t toHash() const @safe nothrow =>
    cast(size_t) ssl ^ cast(size_t) sock.handle;
  bool opEquals(const ClientConnection other) const @safe nothrow =>
    ssl == other.ssl && sock.handle == other.sock.handle;
}

void handleClient(ref ClientConnection client, char[] buffer)
{
  int bytes = SSL_read(client.ssl, buffer.ptr, cast(int) buffer.length);
  if (bytes <= 0)
  {
    auto err = SSL_get_error(client.ssl, bytes);
    if (err == SSL_ERROR_ZERO_RETURN)
      log.info("Client connection terminated gracefully.");
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
    int sent = SSL_write(client.ssl, buffer.ptr + bytesWritten,
                         bytes - bytesWritten);
    if (sent <= 0)
    {
      ERR_print_errors_cb(&log.errorCallback, null);
      break;
    }
    bytesWritten += sent;
  }
}
