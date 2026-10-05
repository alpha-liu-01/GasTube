#ifndef GASTUBE_PULSE_ROUTE_H_
#define GASTUBE_PULSE_ROUTE_H_

// Watch the Pulse native socket. Calls on_unplug from the Pulse thread when a
// wired headset port drops out, a USB audio card goes away, or the droid
// sink leaves output-usb_device.
void gastube_pulse_route_watch(void (*on_unplug)());

#endif
