import os
import logging
import usb.core

class Arctis7PlusChatMix:
    def __init__(self):
        self.log = self._init_log()
        self.log.info("Initializing Arctis 7+ ChatMix script...")

        # Initialize USB device
        try:
            self.dev = usb.core.find(idVendor=0x1038, idProduct=0x220e)
            if self.dev is None:
                raise ValueError("Arctis 7+ device not found.")
            
            # Select interface and endpoint for ChatMix wheel
            self.interface = self.dev[0].interfaces()[7]
            self.interface_num = self.interface.bInterfaceNumber
            self.endpoint = self.interface.endpoints()[0]
            self.addr = self.endpoint.bEndpointAddress
            
            # Detach kernel driver if active
            if self.dev.is_kernel_driver_active(self.interface_num):
                self.dev.detach_kernel_driver(self.interface_num)
        
        except Exception as e:
            self.log.error(f"Failed to initialize Arctis 7+ device: {e}")
            self.die_gracefully()

    def _init_log(self):
        log = logging.getLogger(__name__)
        log.setLevel(logging.DEBUG)
        stdout_handler = logging.StreamHandler()
        stdout_handler.setLevel(logging.INFO)  # Set the console output level to INFO
        stdout_handler.setFormatter(logging.Formatter('%(levelname)8s | %(message)s'))
        log.addHandler(stdout_handler)
        return log

    def _set_default_sink(self):
        try:
            # Run pactl command to set "Combined" as default sink
            os.system("pactl set-default-sink Combined")
            self.log.info("Default sink set to Combined.")
        except Exception as e:
            self.log.error(f"Failed to set default sink: {e}")

    def start_modulator_signal(self):
        self.log.info("Monitoring Arctis 7+ ChatMix wheel...")
        
        # Set default sink to "Combined" once
        self._set_default_sink()

        try:
            while True:
                try:
                    read_input = self.dev.read(self.addr, 64, timeout=1000)
                    default_device_volume = f"{read_input[1]}%"
                    virtual_device_volume = f"{read_input[2]}%"

                    os.system(f'pactl set-sink-volume Combined {default_device_volume}')
                    os.system(f'pactl set-sink-volume Chat {virtual_device_volume}')

                except usb.core.USBError as e:
                    if e.errno == 110:
                        self.log.debug("USB communication timeout")
                    else:
                        self.log.error(f"USB communication error: {e}")
                    continue  # Continue monitoring even after errors
        
        except KeyboardInterrupt:
            self.log.info("Keyboard interrupt received. Exiting...")
            self.die_gracefully()

        except Exception as e:
            self.log.error(f"Error in monitoring ChatMix wheel: {e}")
            self.die_gracefully()

    def die_gracefully(self):
        self.log.info("Exiting Arctis 7+ ChatMix script gracefully.")
        # Add any cleanup operations if necessary
        exit(0)

if __name__ == '__main__':
    a7pcm_service = Arctis7PlusChatMix()
    a7pcm_service.start_modulator_signal()