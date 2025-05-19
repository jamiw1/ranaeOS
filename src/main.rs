#![no_std]
#![no_main]
#![feature(custom_test_frameworks)]
#![test_runner(ranaeOS::test_runner)]
#![reexport_test_harness_main = "test_main"]

use core::panic::PanicInfo;
use ranaeOS::println;

#[unsafe(no_mangle)]
pub extern "C" fn _start() -> ! {
    println!("starting ranaeOS...");
    println!("this may take a while...");
    ranaeOS::init();

    fn stack_overflow() {
        stack_overflow();
    }
    stack_overflow();

    println!("initialized...");


    println!("this is past breakpoint, meaning it didn't crash!");

    #[cfg(test)]
    test_main();

    println!("welcome to ranaeOS!");
    loop {}
}
#[cfg(not(test))]
#[panic_handler]
fn panic(info: &PanicInfo) -> ! {
    println!("{}", info);
    loop {}
}

#[cfg(test)]
#[panic_handler]
fn panic(info: &PanicInfo) -> ! {
    ranaeOS::test_panic_handler(info)
}