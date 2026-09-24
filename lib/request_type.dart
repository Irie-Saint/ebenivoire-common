/// Nature d'un appel au serveur : décide si le jeton part, et s'il doit être
/// valide avant l'envoi.
enum RequestType {
  auth,
  loginAuth, // Login, register
  verify, // Token verification
  refresh, // Refresh token
  protected, // API calls requiring auth
  optionalAuth, // Public, but sends the token if logged in (e.g. product lists
  // so the backend can annotate is_favorite / in_cart per product)
  public; // Public endpoints

  bool get isAuthRequest =>
      this == RequestType.auth || this == RequestType.loginAuth;

  bool get isVerification => this == RequestType.verify;

  bool get requiresTokenValidation =>
      this == RequestType.verify ||
      this == RequestType.refresh ||
      this == RequestType.protected;
}
