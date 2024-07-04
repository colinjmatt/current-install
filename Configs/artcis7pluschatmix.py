import os
import logging
import usb.core
import argparse

class Arctis7PlusChatMix:
    def __init__(self, log_level=logging.INFO):
        self.log = self._init_log(log_level)
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

    def _init_log(self, log_level):
        log = logging.getLogger(__name__)
        log.setLevel(log_level)  # Set the logger level to the specified log level

        stdout_handler = logging.StreamHandler()
        stdout_handler.setLevel(log_level)  # Set the console output level to the specified log level
        stdout_handler.setFormatter(logging.Formatter('%(levelname)8s | %(message)s'))

        log.addHandler(stdout_handler)
        return log

    def _setup_sinks(self):
        try:
            self.log.info("Setting up PipeWire sinks...")
            # Load the combine-sink module
            os.system("pactl load-module module-combine-sink sink_name=Combined sink_properties=device.description=Combined slaves=alsa_output.pci-0000_09_00.1.hdmi-stereo,alsa_output.pci-0000_0b_00.4.analog-stereo,alsa_output.usb-SteelSeries_Arctis_7_-00.analog-stereo")
            # Load the null-sink module for Chat
            os.system("pactl load-module module-null-sink sink_name=Chat sink_properties=device.description=Chat")
            # Load the loopback module for Chat
            os.system("pactl load-module module-loopback source=Chat.monitor sink=alsa_output.usb-SteelSeries_Arctis_7_-00.analog-stereo")
            self.log.info("PipeWire sinks setup completed.")
        except Exception as e:
            self.log.error(f"Failed to set up sinks: {e}")
            self.die_gracefully()

    def _set_default_sink(self):
        try:
            # Run pactl command to set "Combined" as default sink
            os.system("pactl set-default-sink Combined")
            self.log.info("Default sink set to Combined.")
        except Exception as e:
            self.log.error(f"Failed to set default sink: {e}")

    def start_modulator_signal(self):
        self.log.info("Monitoring Arctis 7+ ChatMix wheel...")

        # Setup the virtual sinks
        self._setup_sinks()

        # Set default sink to "Combined" once
        self._set_default_sink()

        try:
            while True:
                try:
                    read_input = self.dev.read(self.addr, 64, timeout=100)  # Reduced timeout to 100ms

                    # Debug: Print the raw input data
                    self.log.debug(f"Read input: {read_input}")

                    # Check if the headset is turned off by validating the input
                    if read_input[0] != 69:
                        self.log.warning("Invalid signal detected from ChatMix wheel (Did you switch it on or off?).")
                        continue

                    default_device_volume = f"{read_input[1]}%"
                    virtual_device_volume = f"{read_input[2]}%"

                    # Debug: Print the volume values
                    self.log.debug(f"Default device volume: {default_device_volume}")
                    self.log.debug(f"Virtual device volume: {virtual_device_volume}")

                    os.system(f'pactl set-sink-volume Combined {default_device_volume}')
                    os.system(f'pactl set-sink-volume Chat {virtual_device_volume}')

                except usb.core.USBError as e:
                    if e.errno == 110:
                        self.log.debug("No data received from chatmix wheel")
                    else:
                        self.log.error(f"Communication error: {e}")
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
    parser = argparse.ArgumentParser(description="Arctis 7+ ChatMix script")
    parser.add_argument('--log-level', default='INFO', choices=['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'],
                        help='Set the logging level (default: INFO)')
    args = parser.parse_args()

    log_level = getattr(logging, args.log_level.upper(), logging.INFO)

    a7pcm_service = Arctis7PlusChatMix(log_level)
    a7pcm_service.start_modulator_signal()