import { Flag } from "@/flag/flag"

const LOOPBACK = new Set(["localhost", "127.0.0.1", "::1"])

type Options = {
  safe_mode?: boolean
  allowed_hosts?: string[]
  disable_dynamic_installs?: boolean
  disable_remote_instructions?: boolean
  disable_remote_mcp?: boolean
}

function clean(input: string[]) {
  return input
    .map((item) => item.trim().toLowerCase())
    .filter(Boolean)
    .filter((item, i, arr) => arr.indexOf(item) === i)
}

function envHosts() {
  const raw = Flag.OPENCODE_ALLOWED_HOSTS
  if (!raw) return [] as string[]
  return clean(raw.split(","))
}

function host(item: string) {
  if (item.includes("://")) {
    const [, tail = ""] = item.split("://")
    const [base] = tail.split("/")
    return (base ?? "").toLowerCase()
  }
  if (item.includes("/")) {
    const [base] = item.split("/")
    return (base ?? "").toLowerCase()
  }
  return item.toLowerCase()
}

function match(input: URL, rule: string) {
  if (rule === "*") return true
  if (rule.startsWith("*.")) {
    const base = rule.slice(2)
    return input.hostname === base || input.hostname.endsWith(`.${base}`)
  }
  const value = host(rule)
  if (value.includes(":")) return input.host === value
  return input.hostname === value
}

export namespace Safe {
  export function on(opts?: Pick<Options, "safe_mode">) {
    if (Flag.OPENCODE_SAFE_MODE) return true
    return opts?.safe_mode === true
  }

  export function hosts(opts?: Pick<Options, "allowed_hosts">) {
    return clean([...envHosts(), ...(opts?.allowed_hosts ?? [])])
  }

  export function allow(url: string | URL, opts?: Pick<Options, "safe_mode" | "allowed_hosts">) {
    if (!on(opts)) return true
    const parsed = url instanceof URL ? url : new URL(url)
    if (parsed.protocol !== "http:" && parsed.protocol !== "https:") return true
    if (LOOPBACK.has(parsed.hostname.toLowerCase())) return true
    const allowlist = hosts(opts)
    return allowlist.some((rule) => match(parsed, rule))
  }

  export function assert(url: string | URL, opts?: Pick<Options, "safe_mode" | "allowed_hosts">) {
    if (allow(url, opts)) return
    const parsed = url instanceof URL ? url : new URL(url)
    const list = hosts(opts)
    const suffix = list.length ? ` Allowed hosts: ${list.join(", ")}.` : ""
    throw new Error(`Blocked outbound request to ${parsed.origin}. Safe mode is enabled.${suffix}`)
  }

  export function dynamic(opts?: Pick<Options, "safe_mode" | "disable_dynamic_installs">) {
    if (Flag.OPENCODE_DISABLE_DYNAMIC_INSTALLS) return true
    if (on(opts)) return true
    return opts?.disable_dynamic_installs === true
  }

  export function instruction(opts?: Pick<Options, "safe_mode" | "disable_remote_instructions">) {
    if (Flag.OPENCODE_DISABLE_REMOTE_INSTRUCTIONS) return true
    if (on(opts)) return true
    return opts?.disable_remote_instructions === true
  }

  export function mcp(opts?: Pick<Options, "safe_mode" | "disable_remote_mcp">) {
    if (Flag.OPENCODE_DISABLE_REMOTE_MCP) return true
    return opts?.disable_remote_mcp === true
  }
}
