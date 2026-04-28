import std.file;
import std.json;
import std.stdio;
import deimos.openssl.ssl;
import config = bunker_alpha.config;
import connection = bunker_alpha.connection;
import log = bunker_alpha.log;
import server = bunker_alpha.server;
import tls = bunker_alpha.tls;

int main(string[] args)
{
  if (args.length < 2)
  {
    log.error("Usage: proxy-program <config.json>");
    return 1;
  }

  auto cfg = new config.Config(args[1]);
  auto sslContext = tls.createServerContext(cfg);

  server.runServer(sslContext, cfg);

  // Clean up.
  SSL_CTX_free(sslContext);
  return 0;
}
