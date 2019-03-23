#!/usr/bin/python
import subprocess
import time
import touchphat

while True:
    @touchphat.on_touch(["Enter"])
    def attach_devices(event):
        subprocess.run(['ssh', 'colin@COLIN-PC', '/usr/local/bin/attach_mouse_keyb.sh'])
        touchphat.led_off("Enter")

    @touchphat.on_touch(["Back"])
    def detach_devices(event):
        subprocess.run(['ssh', 'colin@COLIN-PC', '/usr/local/bin/detach_mouse_keyb.sh'])
        touchphat.led_off("Back")

    @touchphat.on_touch(["A"])
    def detach_devices(event):
        subprocess.run(['ssh', 'colin@COLIN-PC', 'sudo', 'virsh', 'start', 'win-10'])
        touchphat.led_off("A")

    @touchphat.on_touch(["B"])
    def detach_devices(event):
        subprocess.run(['ssh', 'colin@COLIN-PC', 'sudo', 'virsh', 'shutdown', 'win-10'])
        touchphat.led_off("B")

    @touchphat.on_touch(["C"])
    def detach_devices(event):
        subprocess.run(['ssh', 'colin@COLIN-PC', 'sudo', 'virsh', 'start', 'win-10-work'])
        touchphat.led_off("C")

    @touchphat.on_touch(["D"])
    def detach_devices(event):
        subprocess.run(['ssh', 'colin@COLIN-PC', 'sudo', 'virsh', 'shutdown', 'win-10-work'])
        touchphat.led_off("D")

    time.sleep(0.1)
