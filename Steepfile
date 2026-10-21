D = Steep::Diagnostic

target :lib do
  signature "sig", "steep/shims"
  check "lib"

  library "digest", "securerandom", "socket"

  configure_code_diagnostics(D::Ruby.strict)
end
