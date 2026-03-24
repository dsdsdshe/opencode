import { describe, expect, test } from "bun:test"
import { stripNoProxy } from "../../src/util/proxied"

describe("util.proxied", () => {
  test("strips NO_PROXY keys when active", () => {
    const env = stripNoProxy(
      {
        NO_PROXY: "10.90.79.111",
        no_proxy: "10.90.79.111",
        PATH: "/tmp/bin",
      },
      true,
    )

    expect(env.NO_PROXY).toBeUndefined()
    expect(env.no_proxy).toBeUndefined()
    expect(env.PATH).toBe("/tmp/bin")
  })

  test("keeps NO_PROXY keys when inactive", () => {
    const env = stripNoProxy(
      {
        NO_PROXY: "10.90.79.111",
        no_proxy: "10.90.79.111",
        PATH: "/tmp/bin",
      },
      false,
    )

    expect(env.NO_PROXY).toBe("10.90.79.111")
    expect(env.no_proxy).toBe("10.90.79.111")
    expect(env.PATH).toBe("/tmp/bin")
  })
})
