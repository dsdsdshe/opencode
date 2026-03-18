// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

// borrowed from https://github.com/skyline69/balatro-mod-manager
#[cfg(target_os = "linux")]
fn configure_display_backend() -> Option<String> {
    use opencode_lib::linux_windowing::{select_backend, Backend, SessionEnv};
    use std::env;

    let set_env_if_absent = |key: &str, value: &str| {
        if env::var_os(key).is_none() {
            // Safety: called during startup before any threads are spawned, so mutating the
            // process environment is safe.
            unsafe { env::set_var(key, value) };
        }
    };

    let session = SessionEnv::capture();
    let prefer_wayland = opencode_lib::linux_display::read_wayland().unwrap_or(false);
    let decision = select_backend(&session, prefer_wayland)?;

    match decision.backend {
        Backend::X11 => {
            set_env_if_absent("WINIT_UNIX_BACKEND", "x11");
            set_env_if_absent("GDK_BACKEND", "x11");
            set_env_if_absent("WEBKIT_DISABLE_DMABUF_RENDERER", "1");
        }
        Backend::Wayland => {
            set_env_if_absent("WINIT_UNIX_BACKEND", "wayland");
            set_env_if_absent("GDK_BACKEND", "wayland");
            set_env_if_absent("WEBKIT_DISABLE_DMABUF_RENDERER", "1");
        }
        Backend::Auto => {
            set_env_if_absent("GDK_BACKEND", "wayland,x11");
            set_env_if_absent("WEBKIT_DISABLE_DMABUF_RENDERER", "1");
        }
    }

    Some(decision.note)
}

#[cfg(target_os = "windows")]
fn configure_intranet_profile() {
    use std::{env, fs, path::PathBuf};

    let Some(local_app_data) = env::var_os("LOCALAPPDATA") else {
        return;
    };

    let base = PathBuf::from(local_app_data).join("opencode-demo");
    let config = base.join("opencode.json");
    if !config.is_file() {
        return;
    }

    let runtime = base.join("runtime");
    let xdg_config = runtime.join("xdg-config");
    let xdg_data = runtime.join("xdg-data");
    let xdg_cache = runtime.join("xdg-cache");
    let xdg_state = runtime.join("xdg-state");
    let sandbox_home = runtime.join("home");

    let _ = fs::create_dir_all(&xdg_config);
    let _ = fs::create_dir_all(&xdg_data);
    let _ = fs::create_dir_all(&xdg_cache);
    let _ = fs::create_dir_all(&xdg_state);
    let _ = fs::create_dir_all(&sandbox_home);

    let set = |key: &str, value: String| {
        // Safety: called during startup before any threads are spawned.
        unsafe { env::set_var(key, value) };
    };

    let allowed_hosts = fs::read_to_string(&config)
        .ok()
        .and_then(|raw| serde_json::from_str::<serde_json::Value>(&raw).ok())
        .and_then(|json| json.get("security")?.get("allowed_hosts")?.as_array().cloned())
        .map(|hosts| {
            hosts
                .into_iter()
                .filter_map(|item| item.as_str().map(str::to_string))
                .collect::<Vec<_>>()
        })
        .filter(|hosts| !hosts.is_empty());

    set("OPENCODE_CONFIG", config.to_string_lossy().to_string());
    set("OPENCODE_CONFIG_DIR", base.to_string_lossy().to_string());
    set("OPENCODE_DISABLE_PROJECT_CONFIG", "1".to_string());
    set("OPENCODE_SAFE_MODE", "1".to_string());
    if let Some(hosts) = allowed_hosts {
        set("OPENCODE_ALLOWED_HOSTS", hosts.join(","));
    }
    set("OPENCODE_DISABLE_MODELS_FETCH", "1".to_string());
    set("OPENCODE_DISABLE_DYNAMIC_INSTALLS", "1".to_string());
    set("OPENCODE_DISABLE_REMOTE_INSTRUCTIONS", "1".to_string());
    set("OPENCODE_DISABLE_REMOTE_MCP", "1".to_string());
    set("OPENCODE_DISABLE_AUTOUPDATE", "1".to_string());
    set("OPENCODE_DISABLE_DEFAULT_PLUGINS", "1".to_string());
    set("OPENCODE_DISABLE_PROXY", "1".to_string());
    set("XDG_CONFIG_HOME", xdg_config.to_string_lossy().to_string());
    set("XDG_DATA_HOME", xdg_data.to_string_lossy().to_string());
    set("XDG_CACHE_HOME", xdg_cache.to_string_lossy().to_string());
    set("XDG_STATE_HOME", xdg_state.to_string_lossy().to_string());
    set(
        "OPENCODE_TEST_HOME",
        sandbox_home.to_string_lossy().to_string(),
    );
}

fn main() {
    #[cfg(target_os = "windows")]
    configure_intranet_profile();

    let disable_proxy = std::env::var("OPENCODE_DISABLE_PROXY")
        .map(|value| {
            let value = value.trim().to_ascii_lowercase();
            value == "1" || value == "true" || value == "yes" || value == "on"
        })
        .unwrap_or(false);

    if disable_proxy {
        for key in [
            "HTTP_PROXY",
            "HTTPS_PROXY",
            "ALL_PROXY",
            "http_proxy",
            "https_proxy",
            "all_proxy",
        ] {
            // Safety: called during startup before any threads are spawned.
            unsafe { std::env::remove_var(key) };
        }
    }

    // Ensure loopback connections are never sent through proxy settings.
    // Some VPNs/proxies set HTTP_PROXY/HTTPS_PROXY/ALL_PROXY without excluding localhost.
    let mut bypass = vec![
        "127.0.0.1".to_string(),
        "localhost".to_string(),
        "::1".to_string(),
        "uv.tool.huawei.com".to_string(),
    ];

    bypass.extend(
        std::env::var("OPENCODE_ALLOWED_HOSTS")
            .unwrap_or_default()
            .split(',')
            .flat_map(|item| {
                let input = item
                    .trim()
                    .trim_start_matches("http://")
                    .trim_start_matches("https://");
                if input.is_empty() {
                    return Vec::<String>::new();
                }

                if input.starts_with('[') {
                    if let Some(end) = input.find(']') {
                        let host = input[1..end].trim();
                        if host.is_empty() {
                            return vec![input.to_string()];
                        }
                        return vec![input.to_string(), host.to_string()];
                    }
                    return vec![input.to_string()];
                }

                if input.matches(':').count() == 1 {
                    if let Some((host, _)) = input.split_once(':') {
                        let host = host.trim();
                        if host.is_empty() {
                            return vec![input.to_string()];
                        }
                        return vec![input.to_string(), host.to_string()];
                    }
                }

                vec![input.to_string()]
            }),
    );

    let upsert = |key: &str| {
        let mut items = std::env::var(key)
            .unwrap_or_default()
            .split(',')
            .map(|v| v.trim())
            .filter(|v| !v.is_empty())
            .map(|v| v.to_string())
            .collect::<Vec<_>>();

        for host in &bypass {
            if items.iter().any(|v| v.eq_ignore_ascii_case(host)) {
                continue;
            }
            items.push(host.clone());
        }

        // Safety: called during startup before any threads are spawned.
        unsafe { std::env::set_var(key, items.join(",")) };
    };

    upsert("NO_PROXY");
    upsert("no_proxy");

    #[cfg(target_os = "linux")]
    {
        if let Some(backend_note) = configure_display_backend() {
            eprintln!("{backend_note}");
        }
    }

    opencode_lib::run()
}
