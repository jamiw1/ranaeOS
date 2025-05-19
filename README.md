# ranaeOS
### a custom made x86_64 OS made almost entirely in Rust.
currently very early in development, direction is unsure and slow.
not guarenteeing support as this is a hobby project, and i probably don't have *that* much time to actually work on this.
i'll still probably be somewhat active though, so feel free to submit some issues or pull requests and i might add or merge them

requires a nightly build of Rust and QEMU for running

## to build:
run `rustup component add rust-src llvm-tools-preview --toolchain nightly-x86_64-unknown-none`
> only do this once! gets necessary things for the future, like the source to compile and tools, plus nightly build

run `cargo install bootimage`
> installs bootimage, required to boot/run/test ranaeOS during development

you now have the necessary tools, now you can do `cargo run` to try it out or use `cargo bootimage --release` to build a `bootimage-ranaeOS.bin` located in `target/x64_64-ranaeOS/release`

use QEMU or similar virtual machine tools to boot off the `.bin` file, or flash it onto a USB drive to test on real hardware.
for example, using QEMU (on Windows) `qemu-system-x86_64 -drive format=raw,file=path\to\bootimage-ranaeOS.bin` would be the command used to run
