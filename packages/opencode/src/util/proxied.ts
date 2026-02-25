export function proxied() {
  return !!(process.env.HTTP_PROXY || process.env.HTTPS_PROXY || process.env.http_proxy || process.env.https_proxy)
}

function mergeNoProxy(key: string, extra: string[]) {
  const values = (process.env[key] ?? "")
    .split(",")
    .map((v) => v.trim())
    .filter(Boolean)
  const merged = [...values, ...extra].filter(
    (value, index, arr) => arr.findIndex((item) => item.toLowerCase() === value.toLowerCase()) === index,
  )
  if (merged.length === 0) return
  process.env[key] = merged.join(",")
}

function allowedHosts() {
  return (process.env.OPENCODE_ALLOWED_HOSTS ?? "")
    .split(",")
    .map((v) => v.trim())
    .filter(Boolean)
    .flatMap((value) => {
      const input = value.replace(/^https?:\/\//i, "")
      if (!input) return []

      if (input.startsWith("[")) {
        const end = input.indexOf("]")
        if (end <= 1) return [input]
        const host = input.slice(1, end)
        return host ? [input, host] : [input]
      }

      if (input.includes(":") && input.split(":").length === 2) {
        const host = input.split(":")[0]
        return host ? [input, host] : [input]
      }

      return [input]
    })
}

export function configureProxyBypass() {
  const hosts = ["127.0.0.1", "localhost", "::1", ...allowedHosts()]
  mergeNoProxy("NO_PROXY", hosts)
  mergeNoProxy("no_proxy", hosts)
}
