/**
 The MIT License (MIT)
 
 Copyright (c) 2015 Yohei Yoshihara
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import "OpenSSLHelper.h"
#include <Security/Security.h>
#include <pthread/pthread.h>
#include <openssl/crypto.h>
#include "openssl/ssl.h"
#include "openssl/x509.h"

static pthread_mutex_t *lockarray;

static void lock_callback(int mode, int type, char *file, int line)
{
  (void)file;
  (void)line;
  if (mode & CRYPTO_LOCK) {
    pthread_mutex_lock(&(lockarray[type]));
  }
  else {
    pthread_mutex_unlock(&(lockarray[type]));
  }
}

static unsigned long thread_id(void)
{
  unsigned long ret;
  
  ret=(unsigned long)pthread_self();
  return(ret);
}

static void init_locks(void)
{
  int i;
  
  lockarray=(pthread_mutex_t *)OPENSSL_malloc(CRYPTO_num_locks() *
                                              sizeof(pthread_mutex_t));
  for (i=0; i<CRYPTO_num_locks(); i++) {
    pthread_mutex_init(&(lockarray[i]),NULL);
  }
  
  CRYPTO_set_id_callback((unsigned long (*)(void))thread_id);
  CRYPTO_set_locking_callback((void (*)(int, int, const char *, int))lock_callback);
}

static void kill_locks(void)
{
  int i;
  
  CRYPTO_set_locking_callback(NULL);
  for (i=0; i<CRYPTO_num_locks(); i++)
    pthread_mutex_destroy(&(lockarray[i]));
  
  OPENSSL_free(lockarray);
}

pthread_once_t once = PTHREAD_ONCE_INIT;
pthread_key_t key;
void once_func() {
  pthread_key_create(&key, NULL);
}

static int verify_callback(int preverify_ok, X509_STORE_CTX *x509_ctx)
{
  if (preverify_ok == 0) {
    return 1;
  }
  
  STACK_OF(X509) *st = x509_ctx->untrusted;
  NSMutableArray *certs = [NSMutableArray array];
  for (int i = 0; i < sk_X509_num(st); ++i) {
    X509 *cert = sk_X509_value(st, i);
//    X509_print_fp(stdout, cert);

    unsigned char *der = NULL;
    int len = i2d_X509(cert, &der);
    CFDataRef derData = CFDataCreate(NULL, der, len);
    SecCertificateRef secCert = SecCertificateCreateWithData(NULL, derData);
    NSCAssert(secCert != NULL, @"SecCertificateCreateWithData");
    [certs addObject:(id)CFBridgingRelease(secCert)];
    CFRelease(derData);
    OPENSSL_free(der);
  }
  
  OpenSSLHelper *helper = (__bridge OpenSSLHelper *)(pthread_getspecific(key));
  SecPolicyRef policy = SecPolicyCreateSSL(false, (__bridge CFStringRef)helper.hostName);
  SecTrustRef trust;
  OSStatus status = SecTrustCreateWithCertificates((__bridge CFArrayRef)certs, policy, &trust);
  NSCAssert(status == errSecSuccess, @"SecTrustCreateWithCertificates");
  
  SecTrustResultType result;
  status = SecTrustEvaluate(trust, &result);
  NSCAssert(status == errSecSuccess, @"SecTrustEvaluate");

  CFRelease(trust);
  CFRelease(policy);
  
  return helper.certVerifyCallback((OpenSSLPreverify)preverify_ok, status, result, certs);
}

@implementation OpenSSLHelper

+ (void)globalInit
{
  init_locks();
}

+ (void)globalCleanup
{
  kill_locks();
}

- (void)registerCertVerifyCallback:(void *)sslCtx
{
  pthread_once(&once, once_func);
  pthread_setspecific(key, (__bridge const void *)(self));
  SSL_CTX *ctx = (SSL_CTX *)sslCtx;
  SSL_CTX_set_verify(ctx, SSL_VERIFY_PEER | SSL_VERIFY_FAIL_IF_NO_PEER_CERT, verify_callback);
}

@end
