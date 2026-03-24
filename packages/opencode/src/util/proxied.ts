export function proxied() {
  return !!(process.env.HTTP_PROXY || process.env.HTTPS_PROXY || process.env.http_proxy || process.env.https_proxy)
}

const proxyKeys = ["HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy"] as const
const bypassKeys = ["NO_PROXY", "no_proxy"] as const

function proxyDisabled() {
  const value = (process.env.OPENCODE_DISABLE_PROXY ?? "").trim().toLowerCase()
  return value === "1" || value === "true" || value === "yes" || value === "on"
}

function disableProxy() {
  proxyKeys.forEach((key) => {
    delete process.env[key]
  })
}

export function stripNoProxy<T extends Record<string, string | undefined>>(
  env: T,
  active = process.platform === "win32" && process.env.OPENCODE_CLIENT === "desktop",
) {
  if (!active) return env
  bypassKeys.forEach((key) => {
    delete env[key]
  })
  return env
}

export function configureProxy() {
  if (proxyDisabled()) {
    disableProxy()
  }
}
