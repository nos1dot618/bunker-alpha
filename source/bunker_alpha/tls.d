module bunker_alpha.tls;

import deimos.openssl.err;
import deimos.openssl.ssl;
import config = bunker_alpha.config;
import log = bunker_alpha.log;

SSL_CTX* createServerContext(config.Config cfg)
{
  // OpenSSL initialisation.
  SSL_load_error_strings();
  OpenSSL_add_ssl_algorithms();
  // TODO: TLS configuration is weak, harden it.
  auto sslContext = SSL_CTX_new(TLS_server_method());

  // Load certificate and private key.
  auto certificatePath = cfg.get!string("certificate-path");
  auto privateKeyPath = cfg.get!string("key-path");

  if (certificatePath.isNull || privateKeyPath.isNull)
  {
    log.error("\"certificate-path\" and/or \"key-path\" is not configured.");
    SSL_CTX_free(sslContext);
    return null;
  }

  if (SSL_CTX_use_certificate_file(sslContext, certificatePath.get.ptr,
                                   SSL_FILETYPE_PEM) != 1 ||
      SSL_CTX_use_PrivateKey_file(sslContext, privateKeyPath.get.ptr,
                                  SSL_FILETYPE_PEM) != 1 ||
      SSL_CTX_check_private_key(sslContext) != 1)
  {
    log.error("Private key does not match the certificate.");
    SSL_CTX_free(sslContext);
    return null;
  }

  return sslContext;
}
