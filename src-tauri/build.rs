fn main() {
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("macos") {
        cc::Build::new()
            .file("src/player/macos_surface.m")
            .flag("-fobjc-arc")
            .compile("vektortv_surface");
        println!("cargo:rustc-link-lib=framework=AppKit");
        println!("cargo:rustc-link-lib=framework=QuartzCore");
        println!("cargo:rerun-if-changed=src/player/macos_surface.m");
    }
    tauri_build::build();
}
