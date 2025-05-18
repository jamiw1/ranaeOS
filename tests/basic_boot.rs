#![no_std]
#![no_main]
#![feature(custom_test_frameworks)]
#![reexport_test_harness_main = "test_main"]
#![test_runner(ranaeOS::test_runner)]

use core::panic::PanicInfo;
use ranaeOS::println;

#[unsafe(no_mangle)]
pub extern "C" fn _start() -> ! {
    test_main();

    loop {}
}

#[test_case]
fn test_println() {
    println!("test_println output");
}
#[panic_handler]
fn panic(info: &PanicInfo) -> ! {
    ranaeOS::test_panic_handler(info)
}