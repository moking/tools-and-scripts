#! /bin/bash

echo "mask" > /sys/firmware/acpi/interrupts/gpe6F
echo "mask" > /sys/firmware/acpi/interrupts/sci
echo "disable" > /sys/firmware/acpi/interrupts/gpe6F
echo "disable" > /sys/firmware/acpi/interrupts/sci
