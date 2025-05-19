#![no_std]
#![no_main]
#![feature(custom_test_frameworks)]
#![test_runner(ranaeOS::test_runner)]
#![reexport_test_harness_main = "test_main"]

use core::panic::PanicInfo;
use ranaeOS::{hlt_loop, println};

#[unsafe(no_mangle)]
pub extern "C" fn _start() -> ! {
    println!("starting ranaeOS...");
    println!("initializing...");
    ranaeOS::init();
    println!("initialized!");

    #[cfg(test)]
    test_main();

    println!("welcome to ranaeOS!");
    hlt_loop();
}
#[cfg(not(test))]
#[panic_handler]
fn panic(info: &PanicInfo) -> ! {
    println!("{}", info);
    hlt_loop();
}

#[cfg(test)]
#[panic_handler]
fn panic(info: &PanicInfo) -> ! {
    ranaeOS::test_panic_handler(info)
}